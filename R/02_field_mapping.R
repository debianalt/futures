# ──────────────────────────────────────────────────────────────────────
# 02_field_mapping.R
# Quantitative mapping of the OpenAlex database — epistemic geography,
# disciplinary landscape, temporal trajectories, citation leaders,
# keyword clusters, and North-South mismatch.
#
# Usage: Rscript R/02_field_mapping.R   (from github/ root)
# ──────────────────────────────────────────────────────────────────────

library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(forcats)

root <- here::here()
data_dir <- file.path(root, "data")

# ── Load data ────────────────────────────────────────────────────────
works <- read_csv(file.path(data_dir, "works.csv"),
                  col_types = cols(.default = "c"),
                  show_col_types = FALSE) |>
  mutate(
    cited_by_count = as.integer(cited_by_count),
    year = as.integer(year),
    abstract = replace_na(abstract, "")
  )

authorships <- read_csv(file.path(data_dir, "authorships.csv"),
                        col_types = cols(.default = "c"),
                        show_col_types = FALSE)

keywords <- read_csv(file.path(data_dir, "work_keywords.csv"),
                     col_types = cols(.default = "c"),
                     show_col_types = FALSE)

topics <- read_csv(file.path(data_dir, "work_topics.csv"),
                   col_types = cols(.default = "c"),
                   show_col_types = FALSE)

provenance <- read_csv(file.path(data_dir, "search_provenance.csv"),
                       col_types = cols(.default = "c"),
                       show_col_types = FALSE)

cat(sprintf("Total records: %d\n\n", nrow(works)))


# ═══════════════════════════════════════════════════════════════════════
# 1. GEOGRAPHY OF KNOWLEDGE PRODUCTION
# ═══════════════════════════════════════════════════════════════════════
cat(strrep("=", 60), "\n")
cat("1. GEOGRAPHY OF KNOWLEDGE PRODUCTION\n")
cat("    (Who writes about technology & dematerialisation?)\n")
cat(strrep("=", 60), "\n")

# Regional groupings
global_north <- c("US", "GB", "DE", "SE", "NL", "AU", "CA", "AT", "NO",
                  "CH", "FI", "FR", "DK", "BE", "IE", "IT", "ES", "PT",
                  "JP", "NZ", "IS", "LU")
brics  <- c("CN", "BR", "RU", "IN", "ZA")
latam  <- c("AR", "MX", "CL", "CO", "PE", "EC", "UY", "PY", "BO", "VE",
            "CR", "PA", "CU", "DO", "GT", "HN", "SV", "NI")
africa <- c("NG", "KE", "GH", "ET", "TZ", "UG", "ZW", "CM", "SN", "CI",
            "MA", "DZ", "TN", "EG", "MW", "MZ", "RW", "BF", "ML", "NE")

country_counts <- authorships |>
  filter(!is.na(country_code), country_code != "") |>
  count(country_code, sort = TRUE)

total_authorships <- sum(country_counts$n)

region_of <- function(cc) {
  case_when(
    cc %in% global_north ~ "North",
    cc %in% brics        ~ "BRICS",
    cc %in% latam        ~ "LatAm",
    cc %in% africa       ~ "Africa",
    TRUE                 ~ "Other"
  )
}

country_counts <- country_counts |>
  mutate(region = region_of(country_code))

north_n  <- country_counts |> filter(region == "North") |> pull(n) |> sum()
brics_n  <- country_counts |> filter(region == "BRICS") |> pull(n) |> sum()
latam_n  <- country_counts |> filter(region == "LatAm") |> pull(n) |> sum()
africa_n <- country_counts |> filter(region == "Africa") |> pull(n) |> sum()

cat(sprintf("\n  Total author-country links: %d\n", total_authorships))
cat(sprintf("\n  Global North:  %d (%.1f%%)\n", north_n,  100 * north_n / total_authorships))
cat(sprintf("  BRICS:         %d (%.1f%%)\n",  brics_n,  100 * brics_n / total_authorships))
cat(sprintf("  Latin America: %d (%.1f%%)\n",  latam_n,  100 * latam_n / total_authorships))
cat(sprintf("  Africa:        %d (%.1f%%)\n",  africa_n, 100 * africa_n / total_authorships))

cat("\n  Top 25 countries:\n")
top25 <- country_counts |> head(25)
for (i in seq_len(nrow(top25))) {
  r <- top25[i, ]
  pct <- 100 * r$n / total_authorships
  cat(sprintf("    %s: %4d (%5.1f%%) [%s]\n", r$country_code, r$n, pct, r$region))
}


# ═══════════════════════════════════════════════════════════════════════
# 2. DISCIPLINARY LANDSCAPE
# ═══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 60), "\n")
cat("2. DISCIPLINARY LANDSCAPE\n")
cat("    (Which journals/disciplines dominate?)\n")
cat(strrep("=", 60), "\n")

env_sociology <- c("Environmental Sociology", "Organization & Environment",
                   "Society & Natural Resources", "Sociology",
                   "American Journal of Sociology", "Annual Review of Sociology",
                   "Sociological Forum", "Sociological Perspectives",
                   "Sociology Compass", "Social Forces", "Social Problems",
                   "American Sociological Review", "British Journal of Sociology",
                   "Current Sociology", "Environmental Values",
                   "Journal of World-Systems Research")
industrial_ecology <- c("Journal of Industrial Ecology", "Journal of Cleaner Production",
                        "Resources Conservation and Recycling", "Ecological Economics",
                        "Sustainable Production and Consumption",
                        "Environmental Research Letters", "Environmental Science & Technology",
                        "Global Environmental Change")
energy_tech <- c("Energy Research & Social Science", "Energy Policy",
                 "Technological Forecasting and Social Change",
                 "Energies", "Energy", "Renewable and Sustainable Energy Reviews")
sustainability_gen <- c("Sustainability", "Sustainability Science",
                        "Sustainable Development",
                        "Environmental Science and Pollution Research")
political_ecology <- c("Journal of Political Ecology", "Environmental Politics",
                       "Geoforum", "Antipode", "Environment and Planning E")

journal_counts <- works |>
  filter(!is.na(journal), journal != "") |>
  count(journal, sort = TRUE)

classify_journal <- function(j) {
  case_when(
    j %in% env_sociology     ~ "Environmental Sociology",
    j %in% industrial_ecology ~ "Industrial Ecology / Ecol.Econ",
    j %in% energy_tech       ~ "Energy / Technology",
    j %in% sustainability_gen ~ "Sustainability (general)",
    j %in% political_ecology ~ "Political Ecology / Env.Politics",
    TRUE                     ~ "Other"
  )
}

disc_counts <- journal_counts |>
  mutate(discipline = classify_journal(journal)) |>
  group_by(discipline) |>
  summarise(n = sum(n), .groups = "drop") |>
  arrange(desc(n))

total_j <- sum(disc_counts$n)
cat("\n  Disciplinary clusters (approximate):\n")
for (i in seq_len(nrow(disc_counts))) {
  r <- disc_counts[i, ]
  cat(sprintf("    %s: %d (%.1f%%)\n", r$discipline, r$n, 100 * r$n / total_j))
}

cat("\n  Top 30 journals:\n")
for (i in seq_len(min(30, nrow(journal_counts)))) {
  r <- journal_counts[i, ]
  cat(sprintf("    %s: %d\n", r$journal, r$n))
}


# ═══════════════════════════════════════════════════════════════════════
# 3. TEMPORAL TRAJECTORIES
# ═══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 60), "\n")
cat("3. TEMPORAL TRAJECTORIES\n")
cat("    (When did each conversation emerge?)\n")
cat(strrep("=", 60), "\n")

year_counts <- works |>
  filter(!is.na(year)) |>
  count(year) |>
  arrange(year)

cat("\n  Publications by year:\n")
for (i in seq_len(nrow(year_counts))) {
  r <- year_counts[i, ]
  if (r$year >= 1980) {
    bar <- strrep("#", r$n %/% 5)
    cat(sprintf("    %d: %4d %s\n", r$year, r$n, bar))
  }
}

# Median year by snowball seed
snowball_provenance <- provenance |>
  filter(str_starts(query_label, "snowball_")) |>
  inner_join(works |> select(openalex_id, year), by = "openalex_id") |>
  filter(!is.na(year))

cat("\n  Median year by snowball seed:\n")
seed_stats <- snowball_provenance |>
  group_by(query_label) |>
  summarise(
    median_y = median(year),
    mean_y   = mean(year),
    n        = n(),
    .groups  = "drop"
  ) |>
  arrange(query_label)

for (i in seq_len(nrow(seed_stats))) {
  r <- seed_stats[i, ]
  cat(sprintf("    %s: median=%d, mean=%.0f, n=%d\n",
              r$query_label, r$median_y, r$mean_y, r$n))
}


# ═══════════════════════════════════════════════════════════════════════
# 4. MOST CITED WORKS (field-defining)
# ═══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 60), "\n")
cat("4. MOST CITED WORKS (field-defining)\n")
cat(strrep("=", 60), "\n")

top50 <- works |>
  arrange(desc(cited_by_count)) |>
  head(50)

cat("\n  Top 50 most-cited papers in the database:\n")
for (i in seq_len(nrow(top50))) {
  r <- top50[i, ]
  ttl <- str_trunc(r$title, 70)
  jnl <- str_trunc(if_else(is.na(r$journal), "", r$journal), 30)
  cat(sprintf("    %2d. [%s] %s (%d cites) [%s]\n",
              i, r$year, ttl, r$cited_by_count, jnl))
}


# ═══════════════════════════════════════════════════════════════════════
# 5. KEYWORD & TOPIC CLUSTERS
# ═══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 60), "\n")
cat("5. KEYWORD & TOPIC CLUSTERS\n")
cat("    (What concepts dominate the field?)\n")
cat(strrep("=", 60), "\n")

kw_counts <- keywords |>
  mutate(keyword = str_to_lower(keyword)) |>
  filter(str_length(keyword) > 2) |>
  count(keyword, sort = TRUE)

cat("\n  Top 40 keywords:\n")
for (i in seq_len(min(40, nrow(kw_counts)))) {
  r <- kw_counts[i, ]
  cat(sprintf("    %s: %d\n", r$keyword, r$n))
}

topic_counts <- topics |>
  filter(!is.na(topic_name), str_length(topic_name) > 3) |>
  count(topic_name, sort = TRUE)

cat("\n  Top 30 OpenAlex topics:\n")
for (i in seq_len(min(30, nrow(topic_counts)))) {
  r <- topic_counts[i, ]
  cat(sprintf("    %s: %d\n", r$topic_name, r$n))
}


# ═══════════════════════════════════════════════════════════════════════
# 6. NORTH-SOUTH: WHO WRITES vs WHAT IS STUDIED
# ═══════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 60), "\n")
cat("6. NORTH-SOUTH: WHO WRITES vs WHAT IS STUDIED\n")
cat("    (Detecting the epistemic geography)\n")
cat(strrep("=", 60), "\n")

# Regions mentioned in abstracts + titles
south_terms <- list(
  Africa              = c("africa", "african", "sub-saharan"),
  `Latin America`     = c("latin america", "south america", "brazil", "argentina",
                          "mexico", "chile", "colombia", "peru", "mercosur"),
  `South/SE Asia`     = c("india", "indonesia", "bangladesh", "vietnam",
                          "philippines", "thailand", "myanmar", "pakistan"),
  China               = c("china", "chinese"),
  `Middle East`       = c("middle east", "iran", "turkey", "saudi")
)

north_terms <- list(
  `Europe/EU`            = c("europe", "european", "eu-27", "eu-15", "oecd"),
  USA                    = c("united states", "american", " usa ", "u.s."),
  `Global/cross-national` = c("global", "cross-national", "worldwide", "nations")
)

all_terms <- c(south_terms, north_terms)

text_col <- str_to_lower(paste(works$title, works$abstract))

mention_counts <- sapply(all_terms, function(terms) {
  pattern <- paste(terms, collapse = "|")
  sum(str_detect(text_col, pattern))
})

cat("\n  Regions mentioned in titles + abstracts:\n")
for (region in names(sort(mention_counts, decreasing = TRUE))) {
  cat(sprintf("    %s: %d papers\n", region, mention_counts[region]))
}

south_total <- sum(mention_counts[names(south_terms)])
north_total <- sum(mention_counts[names(north_terms)])

cat("\n  MISMATCH INDICATOR:\n")
cat(sprintf("    Authors from Global North: %.1f%%\n",
            100 * north_n / total_authorships))
cat(sprintf("    Papers mentioning Global South regions: %d\n", south_total))
cat(sprintf("    Papers mentioning Europe/USA/Global: %d\n", north_total))

cat("\n  DONE. Database analysed.\n")
