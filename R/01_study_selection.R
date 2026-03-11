# ──────────────────────────────────────────────────────────────────────
# 01_study_selection.R
# Automated study selection from the OpenAlex literature database.
#
# Reads 4,465 works and scores them for relevance to the Sociology
# Compass review on technology, dematerialisation, and sociotechnical
# futures. Outputs shortlist.csv (top 150 candidates).
#
# Scoring dimensions:
#   1. Citation weight (log-normalised cited_by_count)
#   2. Pillar keyword match (6 thematic dictionaries vs title+abstract)
#   3. Internal citation count (how many DB works cite this work)
#   4. Seed proximity (cites or is cited by one of 11 seeds)
#   5. Journal relevance (core journals receive a bonus)
#
# Usage: Rscript R/01_study_selection.R   (from github/ root)
# ──────────────────────────────────────────────────────────────────────

library(readr)
library(dplyr)
library(stringr)
library(tidyr)

# ── Paths ─────────────────────────────────────────────────────────────
root <- here::here()
data_dir <- file.path(root, "data")

# ── 1. Seed papers (11 foundational works) ────────────────────────────
seed_ids <- c(
  "https://openalex.org/W2049941951",   # Borup et al. 2006
  "https://openalex.org/W3092345588",   # Bugden 2022
  "https://openalex.org/W3083280272",   # Dorninger et al. 2021
  "https://openalex.org/W3013031329",   # Haberl et al. 2020
  "https://openalex.org/W651598703",    # Hornborg 2001
  "https://openalex.org/W1504658872",   # Jorgenson & Clark 2012
  "https://openalex.org/W1562678381",   # Mol & Spaargaren 2000
  "https://openalex.org/W3036679823",   # Wiedmann et al. 2020
  "https://openalex.org/W2131621631",   # York & Rosa 2003
  "https://openalex.org/W1572762085"    # Schnaiberg 1980
)

# ── 2. Pillar keyword dictionaries ───────────────────────────────────
pillars <- list(
  tech_material = c(
    "material footprint", "material flow", "domestic material consumption",
    "demateriali[sz]ation", "decoupling", "resource productivity",
    "resource efficiency", "resource use", "resource consumption"
  ),
  technology_indicators = c(
    "\\bR&D\\b", "\\bresearch and development\\b", "\\bpatent",
    "\\bICT\\b", "information.{0,20}communication.{0,20}technolog",
    "economic complexity", "software complexity", "innovat",
    "technolog\\w+\\s+(change|progress|capabilit|transfer)"
  ),
  affluence_confound = c(
    "affluence", "income\\s+(effect|elastic|driv)",
    "\\bGDP\\b.{0,30}(material|resource|footprint|consumption)",
    "scientists.{0,10}warning", "consumption.{0,15}driv",
    "scale\\s+effect", "wealth\\s+effect"
  ),
  displacement = c(
    "ecologically unequal exchange", "unequal exchange",
    "embodied (material|resource|raw)",
    "material.{0,10}(transfer|displacement|outsourc)",
    "footprint.{0,10}(gap|transfer|trade)",
    "consumption.based.{0,10}(account|footprint)",
    "north.south", "global south"
  ),
  ecological_modernisation = c(
    "ecological moderni[sz]ation", "treadmill of production",
    "STIRPAT", "IPAT", "environmental kuznets",
    "green growth", "techno.optimis"
  ),
  sociology_expectations = c(
    "sociology of expectations", "sociotechnical imaginar",
    "sociotechnical future", "promissory",
    "sociology of the future", "performativ.{0,20}expect",
    "techno.{0,5}(promise|vision|narrative)"
  )
)

# ── 3. Core journals (bonus weight) ──────────────────────────────────
core_journals <- c(
  # Environmental sociology
  "Environmental Sociology", "Organization & Environment",
  "American Journal of Sociology", "Annual Review of Sociology",
  "Sociology Compass", "Social Forces",
  # Industrial ecology / ecological economics
  "Journal of Industrial Ecology", "Journal of Cleaner Production",
  "Ecological Economics", "Resources Conservation and Recycling",
  "Environmental Research Letters", "Global Environmental Change",
  "Sustainable Production and Consumption",
  # Energy & technology
  "Energy Research & Social Science", "Energy Policy",
  "Technological Forecasting and Social Change",
  # Political ecology / environmental politics
  "Environmental Politics", "Journal of Political Ecology",
  "Geoforum", "Journal of World-Systems Research",
  # Sustainability science
  "Sustainability Science", "Nature Communications",
  "Nature Sustainability", "One Earth",
  "Science", "Nature",
  # STS / futures
  "Environmental Innovation and Societal Transitions",
  "Futures", "Technology Analysis & Strategic Management",
  "Wiley Interdisciplinary Reviews Climate Change"
)

# ── 4. Load data ─────────────────────────────────────────────────────
cat("Loading database...\n")

works <- read_csv(file.path(data_dir, "works.csv"),
                  col_types = cols(.default = "c"),
                  show_col_types = FALSE) |>
  mutate(
    cited_by_count = as.integer(cited_by_count),
    year = as.integer(year),
    abstract = replace_na(abstract, "")
  )
cat(sprintf("  %d works\n", nrow(works)))

edges <- read_csv(file.path(data_dir, "citation_edges.csv"),
                  col_types = cols(.default = "c"),
                  show_col_types = FALSE)
cat(sprintf("  %d citation edges\n", nrow(edges)))

# ── 5. Match pillars ─────────────────────────────────────────────────
match_pillars <- function(title, abstract, pillar_dict) {
  text <- str_to_lower(paste(title, abstract))
  matched <- character(0)
  for (pname in names(pillar_dict)) {
    for (pat in pillar_dict[[pname]]) {
      if (str_detect(text, regex(pat, ignore_case = TRUE))) {
        matched <- c(matched, pname)
        break
      }
    }
  }
  matched
}

cat("\nScoring works...\n")

# Pre-compute pillar matches for all works
works <- works |>
  rowwise() |>
  mutate(
    pillar_list = list(match_pillars(title, abstract, pillars)),
    n_pillars   = length(pillar_list),
    pillars_str = paste(sort(pillar_list), collapse = ";")
  ) |>
  ungroup()

# ── 6. Compute scoring components ────────────────────────────────────
max_cites <- max(works$cited_by_count, na.rm = TRUE)

# Internal citation count: how many DB works cite each work
internal_counts <- edges |>
  count(cited_id, name = "internal_citations") |>
  rename(openalex_id = cited_id)

works <- works |>
  left_join(internal_counts, by = "openalex_id") |>
  mutate(internal_citations = replace_na(internal_citations, 0L))

max_internal <- max(works$internal_citations)

# Forward/backward citation sets for seed proximity
forward  <- edges |> select(citing_id, cited_id)
backward <- edges |> select(cited_id, citing_id)

compute_seed_proximity <- function(oid) {
  if (oid %in% seed_ids) return(0.5)
  cites    <- forward |> filter(citing_id == oid) |> pull(cited_id)
  cited_by <- backward |> filter(cited_id == oid) |> pull(citing_id)
  if (any(cites %in% seed_ids) || any(cited_by %in% seed_ids)) return(0.3)
  0.0
}

# Vectorised seed proximity (faster than row-by-row)
citing_seeds <- edges |>
  filter(cited_id %in% seed_ids) |>
  distinct(citing_id) |>
  pull(citing_id)

cited_by_seeds <- edges |>
  filter(citing_id %in% seed_ids) |>
  distinct(cited_id) |>
  pull(cited_id)

seed_connected <- unique(c(citing_seeds, cited_by_seeds))

works <- works |>
  mutate(
    # 1. Citation score (log-normalised)
    citation_score = log1p(cited_by_count) / log1p(max_cites),
    # 2. Pillar score
    pillar_score = pmin(n_pillars / 3, 1),
    # 3. Internal score (log-normalised)
    internal_score = log1p(internal_citations) / log1p(max_internal),
    # 4. Seed proximity
    seed_proximity = case_when(
      openalex_id %in% seed_ids     ~ 0.5,
      openalex_id %in% seed_connected ~ 0.3,
      TRUE                            ~ 0.0
    ),
    # 5. Journal bonus
    journal_bonus = if_else(journal %in% core_journals, 0.15, 0.0),
    # Composite score
    total_score = 0.25 * citation_score +
                  0.30 * pillar_score +
                  0.20 * internal_score +
                  0.15 * seed_proximity +
                  0.10 * journal_bonus
  )

# ── 7. Rank and write shortlist ──────────────────────────────────────
shortlist <- works |>
  arrange(desc(total_score)) |>
  mutate(rank = row_number()) |>
  filter(rank <= 150) |>
  select(
    rank, openalex_id, title, year, journal,
    cited_by_count, internal_citations, total_score,
    citation_score, pillar_score, internal_score,
    seed_proximity, journal_bonus, n_pillars,
    pillars = pillars_str
  ) |>
  mutate(across(c(total_score, citation_score, pillar_score,
                   internal_score, seed_proximity, journal_bonus),
                \(x) round(x, 4)))

outpath <- file.path(data_dir, "shortlist.csv")
write_csv(shortlist, outpath)
cat(sprintf("\nWrote %d candidates to %s\n", nrow(shortlist), outpath))

# ── 8. Console summary ───────────────────────────────────────────────
cat(sprintf("\n%s\n", strrep("=", 60)))
cat(sprintf("SHORTLIST SUMMARY (top 150 of %d)\n", nrow(works)))
cat(sprintf("%s\n", strrep("=", 60)))

# Per pillar
cat("\n  Candidates per pillar:\n")
pillar_names <- c("tech_material", "technology_indicators", "affluence_confound",
                  "displacement", "ecological_modernisation", "sociology_expectations")

pillar_counts <- shortlist |>
  separate_longer_delim(pillars, ";") |>
  filter(pillars != "") |>
  count(pillars)

for (p in pillar_names) {
  n <- pillar_counts |> filter(pillars == p) |> pull(n)
  n <- if (length(n) == 0) 0L else n
  cat(sprintf("    %-30s: %4d\n", p, n))
}

# Per decade
cat("\n  Candidates per decade:\n")
decade_counts <- shortlist |>
  filter(!is.na(year)) |>
  mutate(decade = (year %/% 10) * 10) |>
  count(decade) |>
  arrange(decade)

for (i in seq_len(nrow(decade_counts))) {
  cat(sprintf("    %ds: %4d\n", decade_counts$decade[i], decade_counts$n[i]))
}

# Score range
cat(sprintf("\n  Score range: %.4f - %.4f\n",
            min(shortlist$total_score), max(shortlist$total_score)))
cat(sprintf("  Mean score:  %.4f\n", mean(shortlist$total_score)))

# Top 20 preview
cat("\n  Top 20:\n")
top20 <- shortlist |> filter(rank <= 20)
for (i in seq_len(nrow(top20))) {
  r <- top20[i, ]
  ttl <- str_trunc(r$title, 50)
  cat(sprintf("    %3d. [%d] %-50s (score=%.3f, cites=%d, pillars=%d)\n",
              r$rank, r$year, ttl, r$total_score,
              r$cited_by_count, r$n_pillars))
}

cat("\nDone.\n")
