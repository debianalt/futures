"""
Automated study selection from the OpenAlex literature database.
Reads 4,465 works and scores them for relevance to the Sociology Compass
review article on technology, dematerialisation, and sociotechnical futures.

Scoring dimensions:
  1. Citation weight (normalised cited_by_count)
  2. Pillar keyword match (6 thematic dictionaries against title+abstract)
  3. Internal citation count (how many DB works cite this work)
  4. Seed proximity (cites or is cited by one of 11 seeds)
  5. Journal relevance (core journals receive a bonus)

Outputs:
  - shortlist.csv  — top 150 candidates with scores and pillar flags
  - db/coding.csv  — pre-fills abstract_pillar for top candidates
  - Console summary: candidates per pillar, per decade
"""

import csv
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).parent
DB = ROOT / "data"

# -----------------------------------------------------------------------
# 1. Seed papers (11 foundational works)
# -----------------------------------------------------------------------

SEED_IDS = {
    "https://openalex.org/W2049941951",   # Borup et al. 2006
    "https://openalex.org/W3092345588",   # Bugden 2022
    "https://openalex.org/W3083280272",   # Dorninger et al. 2021
    "https://openalex.org/W3013031329",   # Haberl et al. 2020
    "https://openalex.org/W651598703",    # Hornborg 2001
    "https://openalex.org/W1504658872",   # Jorgenson & Clark 2012
    "https://openalex.org/W1562678381",   # Mol & Spaargaren 2000
    "https://openalex.org/W3036679823",   # Wiedmann et al. 2020
    "https://openalex.org/W2131621631",   # York & Rosa 2003
    "https://openalex.org/W1572762085",   # Schnaiberg 1980
    # Parrique et al. 2019 — not found in DB, kept as manual seed
}

# -----------------------------------------------------------------------
# 2. Pillar keyword dictionaries
# -----------------------------------------------------------------------

PILLARS = {
    "tech_material": [
        r"material footprint", r"material flow", r"domestic material consumption",
        r"demateriali[sz]ation", r"decoupling", r"resource productivity",
        r"resource efficiency", r"resource use", r"resource consumption",
    ],
    "technology_indicators": [
        r"\bR&D\b", r"\bresearch and development\b", r"\bpatent",
        r"\bICT\b", r"information.{0,20}communication.{0,20}technolog",
        r"economic complexity", r"software complexity", r"innovat",
        r"technolog\w+\s+(change|progress|capabilit|transfer)",
    ],
    "affluence_confound": [
        r"affluence", r"income\s+(effect|elastic|driv)",
        r"\bGDP\b.{0,30}(material|resource|footprint|consumption)",
        r"scientists.{0,10}warning", r"consumption.{0,15}driv",
        r"scale\s+effect", r"wealth\s+effect",
    ],
    "displacement": [
        r"ecologically unequal exchange", r"unequal exchange",
        r"embodied (material|resource|raw)",
        r"material.{0,10}(transfer|displacement|outsourc)",
        r"footprint.{0,10}(gap|transfer|trade)",
        r"consumption.based.{0,10}(account|footprint)",
        r"north.south", r"global south",
    ],
    "ecological_modernisation": [
        r"ecological moderni[sz]ation", r"treadmill of production",
        r"STIRPAT", r"IPAT", r"environmental kuznets",
        r"green growth", r"techno.optimis",
    ],
    "sociology_expectations": [
        r"sociology of expectations", r"sociotechnical imaginar",
        r"sociotechnical future", r"promissory",
        r"sociology of the future", r"performativ.{0,20}expect",
        r"techno.{0,5}(promise|vision|narrative)",
    ],
}

# -----------------------------------------------------------------------
# 3. Core journals (bonus weight)
# -----------------------------------------------------------------------

CORE_JOURNALS = {
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
    "Wiley Interdisciplinary Reviews Climate Change",
}

# Pillar → section mapping for coding.csv (revised numbering, Aug 2026:
# a methods section was inserted as Section 2)
PILLAR_SECTION = {
    "tech_material": "4.1",
    "technology_indicators": "4.2",
    "affluence_confound": "4.3",
    "displacement": "5",
    "ecological_modernisation": "3.1",
    "sociology_expectations": "3.2",
}


def load_works():
    """Load works.csv into a dict keyed by openalex_id."""
    works = {}
    with open(DB / "works.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            works[row["openalex_id"]] = row
    return works


def load_citation_edges():
    """Load citation_edges.csv into forward and backward maps."""
    forward = defaultdict(set)   # citing_id -> set of cited_ids
    backward = defaultdict(set)  # cited_id -> set of citing_ids
    with open(DB / "citation_edges.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            forward[row["citing_id"]].add(row["cited_id"])
            backward[row["cited_id"]].add(row["citing_id"])
    return forward, backward


def load_keywords():
    """Load work_keywords.csv into a dict: openalex_id -> set of keywords."""
    kws = defaultdict(set)
    with open(DB / "work_keywords.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            kws[row["openalex_id"]].add(row["keyword"].lower())
    return kws


def match_pillars(title, abstract):
    """Return set of pillar names that match title+abstract."""
    text = f"{title} {abstract}".lower()
    matched = set()
    for pillar, patterns in PILLARS.items():
        for pat in patterns:
            if re.search(pat, text, re.IGNORECASE):
                matched.add(pillar)
                break
    return matched


def score_works(works, forward, backward):
    """Score each work and return sorted list of (id, score_dict)."""
    # Pre-compute max cited_by_count for normalisation
    cite_counts = [int(w["cited_by_count"]) for w in works.values()
                   if w["cited_by_count"].isdigit()]
    max_cites = max(cite_counts) if cite_counts else 1

    # Internal citation count (how many DB works cite this work)
    internal_cited = {oid: len(backward.get(oid, set())) for oid in works}
    max_internal = max(internal_cited.values()) if internal_cited else 1

    scored = []
    for oid, row in works.items():
        title = row.get("title", "")
        abstract = row.get("abstract", "") or ""
        year = int(row["year"]) if row["year"].isdigit() else 0
        cited_by = int(row["cited_by_count"]) if row["cited_by_count"].isdigit() else 0
        journal = row.get("journal", "")

        # 1. Citation weight (0-1, log-normalised)
        import math
        citation_score = math.log1p(cited_by) / math.log1p(max_cites)

        # 2. Pillar keyword match (0-1)
        pillars = match_pillars(title, abstract)
        pillar_score = min(len(pillars) / 3.0, 1.0)  # 3+ pillars = max

        # 3. Internal citation count (0-1, log-normalised)
        ic = internal_cited.get(oid, 0)
        internal_score = math.log1p(ic) / math.log1p(max_internal) if max_internal > 0 else 0

        # 4. Seed proximity (0 or 0.3)
        # Check if this work cites a seed or is cited by a seed
        seed_prox = 0.0
        if oid in SEED_IDS:
            seed_prox = 0.5  # seed itself
        else:
            cites_set = forward.get(oid, set())
            cited_by_set = backward.get(oid, set())
            if cites_set & SEED_IDS or cited_by_set & SEED_IDS:
                seed_prox = 0.3

        # 5. Journal relevance (0 or 0.15)
        journal_bonus = 0.15 if journal in CORE_JOURNALS else 0.0

        # Composite score (weighted sum)
        total = (
            0.25 * citation_score +
            0.30 * pillar_score +
            0.20 * internal_score +
            0.15 * seed_prox +
            0.10 * journal_bonus
        )

        scored.append({
            "openalex_id": oid,
            "title": title,
            "year": year,
            "journal": journal,
            "cited_by_count": cited_by,
            "internal_citations": ic,
            "citation_score": round(citation_score, 3),
            "pillar_score": round(pillar_score, 3),
            "internal_score": round(internal_score, 3),
            "seed_proximity": round(seed_prox, 3),
            "journal_bonus": round(journal_bonus, 3),
            "total_score": round(total, 4),
            "pillars": ";".join(sorted(pillars)),
            "n_pillars": len(pillars),
        })

    scored.sort(key=lambda x: -x["total_score"])
    return scored


def write_shortlist(scored, n=150):
    """Write top-N candidates to shortlist.csv."""
    outpath = ROOT / "shortlist.csv"
    fields = [
        "rank", "openalex_id", "title", "year", "journal",
        "cited_by_count", "internal_citations", "total_score",
        "citation_score", "pillar_score", "internal_score",
        "seed_proximity", "journal_bonus", "n_pillars", "pillars",
    ]
    with open(outpath, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for i, row in enumerate(scored[:n]):
            row["rank"] = i + 1
            w.writerow({k: row[k] for k in fields})
    print(f"\nWrote {min(n, len(scored))} candidates to {outpath}")


def update_coding(scored, n=150):
    """Pre-fill abstract_pillar in coding.csv for top candidates."""
    # Load existing coding.csv
    coding = {}
    coding_path = DB / "coding.csv"
    with open(coding_path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            coding[row["openalex_id"]] = row

    # Map top candidates' primary pillar
    top_ids = {}
    for row in scored[:n]:
        pillars = row["pillars"].split(";") if row["pillars"] else []
        if pillars:
            # Primary pillar = first match in priority order
            priority = ["tech_material", "technology_indicators", "affluence_confound",
                        "displacement", "ecological_modernisation", "sociology_expectations"]
            primary = next((p for p in priority if p in pillars), pillars[0])
            top_ids[row["openalex_id"]] = primary

    updated = 0
    for oid, pillar in top_ids.items():
        if oid in coding:
            if not coding[oid].get("abstract_pillar"):
                coding[oid]["abstract_pillar"] = pillar
                section = PILLAR_SECTION.get(pillar, "")
                if not coding[oid].get("section_relevance"):
                    coding[oid]["section_relevance"] = section
                updated += 1

    # Write back
    with open(coding_path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for row in coding.values():
            w.writerow(row)

    print(f"Updated {updated} entries in {coding_path}")


def print_summary(scored, n=150):
    """Console summary of shortlist composition."""
    top = scored[:n]

    print(f"\n{'='*60}")
    print(f"SHORTLIST SUMMARY (top {n} of {len(scored)})")
    print(f"{'='*60}")

    # Per pillar
    pillar_counts = Counter()
    for row in top:
        for p in row["pillars"].split(";"):
            if p:
                pillar_counts[p] += 1

    print(f"\n  Candidates per pillar:")
    for p in ["tech_material", "technology_indicators", "affluence_confound",
              "displacement", "ecological_modernisation", "sociology_expectations"]:
        print(f"    {p:30s}: {pillar_counts.get(p, 0):>4}")

    # Per decade
    decade_counts = Counter()
    for row in top:
        if row["year"]:
            decade = (row["year"] // 10) * 10
            decade_counts[decade] += 1

    print(f"\n  Candidates per decade:")
    for d in sorted(decade_counts):
        print(f"    {d}s: {decade_counts[d]:>4}")

    # Score distribution
    scores = [r["total_score"] for r in top]
    print(f"\n  Score range: {min(scores):.4f} - {max(scores):.4f}")
    print(f"  Mean score:  {sum(scores)/len(scores):.4f}")

    # Top 20 preview
    print(f"\n  Top 20:")
    for row in top[:20]:
        author = row["title"][:50]
        print(f"    {row['rank']:>3}. [{row['year']}] {author:50s} "
              f"(score={row['total_score']:.3f}, cites={row['cited_by_count']}, "
              f"pillars={row['n_pillars']})")


def main():
    print("Loading database...")
    works = load_works()
    print(f"  {len(works)} works")
    forward, backward = load_citation_edges()
    print(f"  {sum(len(v) for v in forward.values())} citation edges")

    print("\nScoring works...")
    scored = score_works(works, forward, backward)

    write_shortlist(scored, n=150)
    update_coding(scored, n=150)
    print_summary(scored, n=150)


if __name__ == "__main__":
    main()
