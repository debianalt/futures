"""
Targeted second screen of the records below the ranking threshold.

Reproduces, from db/works.csv and the composite relevance score of
select_studies.py, the selection of below-threshold records that were
screened at title and abstract in August 2026. Four rules, applied to the
4,315 records ranked below position 150:

  R1  two or more of the six pillar keyword dictionaries matched
  R2  a material-outcome term (tech_material dictionary) together with a
      cross-national cue (country, nation, panel, global, OECD, European,
      world) in title or abstract
  R3  no abstract available in OpenAlex and a material-outcome term in the
      title
  R4  a displacement term (displacement dictionary) together with a
      cross-national cue

A record is selected if any rule fires. The script writes
db/targeted_screen_selection.csv (openalex_id, rank, score, rules) and
asserts that the selection contains exactly the 407 records screened.

Run: python targeted_screen.py
"""

import csv
import re
from pathlib import Path

import select_studies as ss

ROOT = Path(__file__).parent
DB = ROOT / "data"
THRESHOLD = 150
EXPECTED = 407

CUE = re.compile(r"countr|nation|cross-national|panel|global|OECD|european|world", re.I)
MATERIAL = re.compile("|".join(ss.PILLARS["tech_material"]), re.I)
DISPLACEMENT = re.compile("|".join(ss.PILLARS["displacement"]), re.I)


def main():
    works = ss.load_works()
    forward, backward = ss.load_citation_edges()
    scored = ss.score_works(works, forward, backward)
    rank = {r["openalex_id"]: i + 1 for i, r in enumerate(scored)}

    selected = []
    for r in scored[THRESHOLD:]:
        w = works[r["openalex_id"]]
        title = w.get("title") or ""
        abstract = (w.get("abstract") or "").strip()
        text = f"{title} {abstract}"
        pillars = set(r["pillars"].split(";")) if r["pillars"] else set()
        rules = []
        if r["n_pillars"] >= 2:
            rules.append("R1")
        if "tech_material" in pillars and CUE.search(text):
            rules.append("R2")
        if not abstract and MATERIAL.search(title):
            rules.append("R3")
        if "displacement" in pillars and CUE.search(text):
            rules.append("R4")
        if rules:
            selected.append({"openalex_id": r["openalex_id"], "rank": rank[r["openalex_id"]],
                             "total_score": r["total_score"], "rules": ";".join(rules),
                             "has_abstract": bool(abstract), "title": title})

    out = DB / "targeted_screen_selection.csv"
    with open(out, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(selected[0].keys()))
        w.writeheader()
        for row in selected:
            w.writerow(row)

    print(f"Records below rank {THRESHOLD}: {len(scored) - THRESHOLD:,}")
    print(f"Selected by the four rules: {len(selected)}")
    for rule in ("R1", "R2", "R3", "R4"):
        print(f"  {rule}: {sum(1 for s in selected if rule in s['rules'])}")
    print(f"Written: {out}")
    assert len(selected) == EXPECTED, f"expected {EXPECTED}, got {len(selected)}"


if __name__ == "__main__":
    main()
