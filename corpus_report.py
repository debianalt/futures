"""
Corpus report for the Sociology Compass review (manuscript 5519565, R1).

Single source of truth for every count reported in the manuscript, the
supplementary information, and the search protocol. Reads db/coding.csv and
db/additional_records.csv and prints:

  - the identification/screening/inclusion funnel
  - the final corpus with per-pillar and per-source composition
  - the distribution of decoupling findings across the corpus
  - open [VERIFICAR] items still requiring source checks

Any number appearing in the manuscript that disagrees with this report is
wrong by definition. Run: python corpus_report.py
"""

import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).parent
DB = ROOT / "data"

# Fixed identification-stage numbers (from openalex_search.py provenance log)
N_QUERIES = 2655
N_SNOWBALL = 2415
N_SEEDS = 9
N_TOTAL = 5079
N_DEDUP = 4465
N_SHORTLIST = 150


def load(path):
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def main():
    coding = load(DB / "coding.csv")
    additional = load(DB / "additional_records.csv")

    db_included = [r for r in coding if r.get("include_final") == "yes"]
    add_included = [r for r in additional if r.get("include_final") == "yes"]
    corpus = db_included + add_included

    framework = [r for r in coding
                 if "interpretive framework source" in r.get("exclusion_reason", "")]
    screened = [r for r in coding if r.get("assessed_stage") == "candidate_screen"]

    print("=" * 64)
    print("IDENTIFICATION AND SCREENING FUNNEL")
    print("=" * 64)
    print(f"Structured OpenAlex queries:            {N_QUERIES:>6,}")
    print(f"Citation snowball (9 seeds):            {N_SNOWBALL:>6,}")
    print(f"Seeds:                                  {N_SEEDS:>6,}")
    print(f"Total records:                          {N_TOTAL:>6,}")
    print(f"After deduplication (ranked by score):  {N_DEDUP:>6,}")
    print(f"Top-ranked candidates read in full:     {N_SHORTLIST:>6,}")
    print(f"  (marked candidate_screen, excluded):  {len(screened):>6,}")
    print(f"Included from database:                 {len(db_included):>6,}")
    print(f"Additional records (citation search):   {len(add_included):>6,}")
    print(f"FINAL CORPUS:                           {len(corpus):>6,}")
    print(f"Interpretive framework sources (in DB,"
          f" not corpus):                           {len(framework):>6,}")

    print()
    print("=" * 64)
    print("CORPUS COMPOSITION")
    print("=" * 64)
    pillar = Counter(r["abstract_pillar"] for r in corpus)
    print("Per pillar:")
    for k, v in pillar.most_common():
        print(f"  {k:32s} {v:>3}")
    tech_total = pillar.get("tech_material", 0) + pillar.get("affluence_confound", 0)
    print(f"  {'technology-material total':32s} {tech_total:>3}"
          "  (affluence_confound is a sub-label of the technology-material pillar)")
    dual = [r for r in corpus if r.get("notes", "").startswith("dual pillar:")]
    print(f"  (dual-coverage studies also informing"
          f" displacement: {len(dual)})")

    print("\nPer study type:")
    for k, v in Counter(r["study_type"] for r in corpus).most_common():
        print(f"  {k:44s} {v:>3}")

    print("\nDecoupling-support distribution:")
    for k, v in Counter(r["supports_decoupling"] for r in corpus).most_common():
        print(f"  {k:44s} {v:>3}")

    tabulated = [r for r in corpus
                 if r["abstract_pillar"] in ("tech_material", "affluence_confound")
                 and "not tabulated" not in r.get("notes", "")]
    print(f"\nTable 1 rows (technology-material corpus,"
          f" tabulated): {len(tabulated)}")

    print()
    print("=" * 64)
    print("OPEN [VERIFICAR] ITEMS")
    print("=" * 64)
    n_open = 0
    for r in corpus:
        joined = " ".join(r.values())
        if "VERIFICAR" in joined:
            n_open += 1
            label = r.get("citation") or r.get("openalex_id")
            print(f"  {label}")
            print(f"    -> {r.get('notes', '')}")
    if n_open == 0:
        print("  none")
    print(f"\nTotal open items: {n_open}")


if __name__ == "__main__":
    main()
