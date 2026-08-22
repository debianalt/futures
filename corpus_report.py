"""
Corpus report for the Sociology Compass review (manuscript 5519565, R1).

Single source of truth for every count reported in the manuscript, the
supplementary information, and the search protocol. Reads db/coding.csv and
db/additional_records.csv and prints:

  - the identification / ranking / screening / inclusion funnel, including
    the targeted second screen of the records below the ranking threshold
  - the final corpus with per-pillar, per-source and per-basis composition
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


def line(label, value):
    print(f"{label:<54s}{value:>8,}")


def funnel(coding, additional):
    """Return every count used in the manuscript, SI, protocol and figure."""
    f = {}
    shortlist_path = next(p for p in (ROOT / "shortlist.csv", DB / "shortlist.csv") if p.exists())
    top_ids = {r["openalex_id"] for r in load(shortlist_path)}
    assert len(top_ids) == N_SHORTLIST, len(top_ids)
    top = [r for r in coding if r["openalex_id"] in top_ids]
    assert all(r["assessed_stage"] == "full_text" for r in top)
    f["top_framework"] = sum(1 for r in top if "interpretive framework source" in r.get("exclusion_reason", ""))
    f["top_included"] = sum(1 for r in top if r["include_final"] == "yes")
    f["top_excluded"] = len(top) - f["top_framework"] - f["top_included"]
    # the two known-item retrievals below the threshold are coded full_text; separate them
    known = [r for r in coding if r["include_final"] == "yes" and r["openalex_id"] in KNOWN_ITEM]
    assert len(known) == 2
    f["known_item_outside_rules"] = sum(1 for r in known if r.get("screen_code") != "INCLUDED")  # Knight & Rosa (rank 447)
    f["known_item_in_rules"] = sum(1 for r in known if r.get("screen_code") == "INCLUDED")        # Steinberger (rank 284)
    in_rules = [r for r in coding if r.get("screen_code")]
    f["screened"] = len(in_rules)
    f["screen_excluded"] = sum(1 for r in in_rules if r["assessed_stage"] == "targeted_screen")
    assessed = [r for r in in_rules if r["assessed_stage"] in ("targeted_full_text", "targeted_abstract") or r.get("screen_code") == "INCLUDED"]
    f["assessed"] = len(assessed)
    f["assessed_full"] = sum(1 for r in assessed if r["assessed_stage"] in ("targeted_full_text", "full_text"))
    f["assessed_abstract"] = sum(1 for r in assessed if r["assessed_stage"] == "targeted_abstract")
    inc = [r for r in assessed if r["include_final"] == "yes"]
    f["t_included"] = len(inc)
    f["t_included_full"] = sum(1 for r in inc if r["assessed_stage"] in ("targeted_full_text", "full_text"))
    f["t_included_abstract"] = sum(1 for r in inc if r["assessed_stage"] == "targeted_abstract")
    f["t_not_assessable"] = sum(1 for r in assessed if r["exclusion_reason"].startswith("not assessable"))
    f["t_excluded_criteria"] = f["assessed"] - f["t_included"] - f["t_not_assessable"]
    f["below"] = N_DEDUP - N_SHORTLIST
    f["db_included"] = sum(1 for r in coding if r["include_final"] == "yes")
    f["add_included"] = sum(1 for r in additional if r.get("include_final") == "yes")
    f["corpus"] = f["db_included"] + f["add_included"]
    return f


KNOWN_ITEM = {"https://openalex.org/W2133907326",   # Steinberger et al. 2013 (rank 284, selected by rule R2)
              "https://openalex.org/W2140726154"}   # Knight & Rosa 2011 (rank 447, outside the rules)


def main():
    coding = load(DB / "coding.csv")
    additional = load(DB / "additional_records.csv")
    f = funnel(coding, additional)
    db_included = [r for r in coding if r["include_final"] == "yes"]
    add_included = [r for r in additional if r.get("include_final") == "yes"]
    corpus = db_included + add_included

    print("=" * 64)
    print("IDENTIFICATION, RANKING, SCREENING AND INCLUSION FUNNEL")
    print("=" * 64)
    line("Structured OpenAlex queries:", N_QUERIES)
    line("Citation snowball (9 seeds):", N_SNOWBALL)
    line("Seeds:", N_SEEDS)
    line("Total records:", N_TOTAL)
    line("After deduplication (ranked by composite score):", N_DEDUP)
    line("Top-ranked candidates read in full:", N_SHORTLIST)
    line("  did not meet the criteria:", f["top_excluded"])
    line("  retained as framework sources:", f["top_framework"])
    line("  included:", f["top_included"])
    line("Below the ranking threshold:", f["below"])
    line("  selected by the four rules (targeted screen):", f["screened"])
    line("  excluded at title and abstract:", f["screen_excluded"])
    line("  assessed for eligibility:", f["assessed"])
    line("    on the full text:", f["assessed_full"])
    line("    on the abstract (full text not retrievable):", f["assessed_abstract"])
    line("  included from the targeted screen:", f["t_included"])
    line("    coded from the full text:", f["t_included_full"])
    line("    coded from the abstract:", f["t_included_abstract"])
    line("  excluded on the criteria:", f["t_excluded_criteria"])
    line("  not assessable:", f["t_not_assessable"])
    line("  known item retrieved outside the rules (rank 447):", f["known_item_outside_rules"])
    line("Included from the database:", f["db_included"])
    line("Additional records (citation search):", f["add_included"])
    line("FINAL CORPUS:", f["corpus"])
    line("Interpretive framework sources (in DB, not corpus):", sum(1 for r in coding if "interpretive framework source" in r.get("exclusion_reason", "")))
    assert f["screened"] == 407, f["screened"]
    assert f["screen_excluded"] + f["assessed"] == f["screened"]
    assert f["top_included"] + f["t_included"] + f["known_item_outside_rules"] == f["db_included"], f
    stages = Counter(r["assessed_stage"] for r in coding)
    assert sum(stages.values()) == N_DEDUP

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
    dual = [r for r in corpus if "dual pillar:" in r.get("notes", "")]
    print(f"  (dual-coverage studies also informing displacement: {len(dual)})")

    print("\nPer source and basis:")
    print(f"  {'database, top-150 (full text)':46s} {f['top_included']:>3}")
    print(f"  {'database, targeted screen (full text)':46s} {f['t_included_full']:>3}")
    print(f"  {'database, targeted screen (abstract)':46s} {f['t_included_abstract']:>3}")
    print(f"  {'database, known item outside the rules':46s} {f['known_item_outside_rules']:>3}")
    print(f"  {'citation search (full text)':46s} {f['add_included']:>3}")

    tierc = [r for r in corpus if "tier C" in r.get("notes", "")]
    print(f"\nPanel-econometric innovation studies (tier C group): {len(tierc)}")

    print("\nDecoupling-category distribution (technology-material corpus):")
    tm = [r for r in corpus if r["abstract_pillar"] in ("tech_material", "affluence_confound")]
    for k, v in Counter(r.get("decoupling_category") or "uncategorised" for r in tm).most_common():
        print(f"  {k:44s} {v:>3}")

    tabulated = [r for r in corpus
                 if r["abstract_pillar"] in ("tech_material", "affluence_confound")
                 and "not tabulated" not in r.get("notes", "")]
    print("\nTechnology indicator groups (tabulated technology-material corpus):")
    for k, v in Counter(indicator_group(r) for r in tabulated).most_common():
        print(f"  {k:52s} {v:>3}")
    print(f"\nTable 1 rows (technology-material corpus, tabulated): {len(tabulated)}")

    print()
    print("=" * 64)
    print("OPEN [VERIFICAR] ITEMS")
    print("=" * 64)
    n_open = 0
    for r in corpus:
        if "VERIFICAR" in " ".join(r.values()):
            n_open += 1
            print(f"  {r.get('citation') or r.get('openalex_id')}")
    if n_open == 0:
        print("  none")
    print(f"\nTotal open items: {n_open}")


def indicator_group(r):
    t = (r.get("tech_indicator") or "").lower()
    if t.startswith("none") or "assessed directly" in t or "tested directly" in t or "no technology proxy" in t:
        return "decoupling assessed directly (no named indicator)"
    if t.strip() == "various":
        return "reviews (various indicators)"
    if "r&d" in t or "research and development" in t:
        return "R&D intensity (with or without patents)"
    if "complexity" in t:
        return "economic complexity"
    if "ict" in t or "digital" in t or "internet" in t:
        return "ICT diffusion / digitalisation"
    if "patent" in t or "innovation" in t or "green technolog" in t or "eco-innov" in t:
        return "patents / innovation indicators"
    if "stirpat" in t or "ipat" in t or "modernisation prox" in t or "kaya" in t:
        return "STIRPAT / IPAT technology term"
    if "renewable" in t or "alternative" in t or "energy mix" in t or "energy transition" in t or "clean energy" in t:
        return "alternative-energy capacity / renewable share"
    if "efficien" in t or "productivity" in t or "intensity" in t or "exergy" in t or "technology-adjusted" in t or "material-efficiency" in t:
        return "efficiency / intensity measures"
    if "carbon pricing" in t or "policy" in t:
        return "policy instruments"
    return "other / scenario"


if __name__ == "__main__":
    main()
