"""
OpenAlex Literature Search — Internal quantitative database
Article: "Sociotechnical Futures and Material Realities"

This script builds a comprehensive literature database via OpenAlex API.
Identification stage of the structured evidence review (see docs/search_protocol.md).

Strategy:
  1. Locate 11 seed papers by DOI
  2. Forward citation snowball from seeds (who cites them?)
  3. Keyword searches (3 queries matching the abstract's 3 pillars)
  4. Merge, deduplicate, enrich with author geography + discipline
  5. Export to CSV
"""

import requests
import csv
import time
import json
from collections import defaultdict
from pathlib import Path

MAILTO = "your.email@example.org"  # OpenAlex polite-pool contact; replace before running
BASE = "https://api.openalex.org"
OUTDIR = Path(".")
SLEEP = 0.12  # ~8 req/s, well within polite pool limits


def api_get(endpoint, params=None):
    """Query OpenAlex API with polite pool."""
    if params is None:
        params = {}
    params["mailto"] = MAILTO
    time.sleep(SLEEP)
    r = requests.get(f"{BASE}/{endpoint}", params=params)
    r.raise_for_status()
    return r.json()


def get_work_by_doi(doi):
    """Fetch a single work by DOI."""
    try:
        return api_get(f"works/doi:{doi}")
    except Exception as e:
        print(f"  WARNING: Could not fetch DOI {doi}: {e}")
        return None


def search_works(search_query, filters=None, max_results=500):
    """
    Search OpenAlex works with pagination.
    Returns list of work objects.
    """
    works = []
    params = {
        "search": search_query,
        "per_page": 100,
        "sort": "cited_by_count:desc",
    }
    if filters:
        params["filter"] = filters

    cursor = "*"
    while cursor and len(works) < max_results:
        params["cursor"] = cursor
        try:
            data = api_get("works", params)
        except Exception as e:
            print(f"  ERROR in search: {e}")
            break

        results = data.get("results", [])
        if not results:
            break

        works.extend(results)
        cursor = data.get("meta", {}).get("next_cursor")
        print(f"    ... fetched {len(works)} / {data['meta']['count']} total")

        if len(results) < 100:
            break

    return works[:max_results]


def get_citing_works(openalex_id, max_results=300):
    """Get works that cite a given work (forward snowball)."""
    short_id = openalex_id.replace("https://openalex.org/", "")
    works = []
    params = {
        "filter": f"cites:{short_id}",
        "per_page": 100,
        "sort": "cited_by_count:desc",
    }
    cursor = "*"
    while cursor and len(works) < max_results:
        params["cursor"] = cursor
        try:
            data = api_get("works", params)
        except Exception as e:
            print(f"  ERROR fetching citations: {e}")
            break

        results = data.get("results", [])
        if not results:
            break

        works.extend(results)
        cursor = data.get("meta", {}).get("next_cursor")

        if len(results) < 100:
            break

    return works[:max_results]


def extract_metadata(work):
    """Extract structured metadata from an OpenAlex work object."""
    if not work:
        return None

    # Authors and their countries
    authorships = work.get("authorships", [])
    authors = []
    author_countries = []
    author_institutions = []
    for a in authorships:
        name = a.get("author", {}).get("display_name", "Unknown")
        authors.append(name)
        for inst in a.get("institutions", []):
            cc = inst.get("country_code", "")
            inst_name = inst.get("display_name", "")
            if cc and cc not in author_countries:
                author_countries.append(cc)
            if inst_name and inst_name not in author_institutions:
                author_institutions.append(inst_name)

    # Journal / source
    source = work.get("primary_location", {}) or {}
    source_obj = source.get("source", {}) or {}
    journal = source_obj.get("display_name", "")
    source_type = source_obj.get("type", "")

    # Topics and concepts
    topics = work.get("topics", [])
    topic_names = [t.get("display_name", "") for t in topics[:5]]

    # Keywords
    keywords = work.get("keywords", [])
    keyword_names = [k.get("keyword", "") for k in keywords[:10]]

    # Abstract (inverted index → plain text)
    abstract_inv = work.get("abstract_inverted_index", {})
    abstract_text = ""
    if abstract_inv:
        # Reconstruct abstract from inverted index
        word_positions = []
        for word, positions in abstract_inv.items():
            for pos in positions:
                word_positions.append((pos, word))
        word_positions.sort()
        abstract_text = " ".join(w for _, w in word_positions)

    # DOI
    doi = work.get("doi", "") or ""
    doi = doi.replace("https://doi.org/", "")

    # Type
    work_type = work.get("type", "")

    # Open access
    oa = work.get("open_access", {}) or {}
    is_oa = oa.get("is_oa", False)

    return {
        "openalex_id": work.get("id", ""),
        "doi": doi,
        "title": work.get("title", "") or "",
        "year": work.get("publication_year", ""),
        "authors": "; ".join(authors),
        "author_countries": "; ".join(author_countries),
        "author_institutions": "; ".join(author_institutions),
        "journal": journal,
        "source_type": source_type,
        "work_type": work_type,
        "cited_by_count": work.get("cited_by_count", 0),
        "is_oa": is_oa,
        "topics": "; ".join(topic_names),
        "keywords": "; ".join(keyword_names),
        "abstract": abstract_text[:2000],  # truncate very long abstracts
    }


# ============================================================
# MAIN
# ============================================================

def main():
    all_works = {}  # openalex_id -> {metadata + source_query}

    def add_works(works_list, source_label):
        """Add works to the master dict, tracking where they came from."""
        added = 0
        for w in works_list:
            oid = w.get("id", "")
            if not oid:
                continue
            meta = extract_metadata(w)
            if not meta:
                continue
            if oid not in all_works:
                meta["source_queries"] = source_label
                all_works[oid] = meta
                added += 1
            else:
                # Already exists — append source query
                existing = all_works[oid]["source_queries"]
                if source_label not in existing:
                    all_works[oid]["source_queries"] = f"{existing}; {source_label}"
        return added

    # ----------------------------------------------------------
    # STEP 1: Locate seed papers by DOI
    # ----------------------------------------------------------
    print("=" * 60)
    print("STEP 1: Locating seed papers by DOI")
    print("=" * 60)

    seed_dois = {
        "Borup et al. 2006": "10.1080/09537320600777002",
        "Bugden 2022": "10.1080/23251042.2020.1824289",
        "Dorninger et al. 2021": "10.1016/j.ecolecon.2021.106824",
        "Haberl et al. 2020": "10.1088/1748-9326/ab842a",
        "Jorgenson & Clark 2012": "10.1086/665990",
        "Mol & Spaargaren 2000": "10.1080/09644010008414511",
        "Wiedmann et al. 2020": "10.1038/s41467-020-16941-y",
        "York & Rosa 2003": "10.1177/1086026603256299",
    }
    # These don't have standard DOIs (books/reports)
    seed_search = {
        "Hornborg 2001": "The Power of the Machine Global Inequalities",
        "Schnaiberg 1980": "The Environment From Surplus to Scarcity",
        "Parrique et al. 2019": "Decoupling Debunked Evidence arguments green growth",
    }

    seed_ids = []

    for label, doi in seed_dois.items():
        w = get_work_by_doi(doi)
        if w:
            meta = extract_metadata(w)
            meta["source_queries"] = "seed"
            all_works[w["id"]] = meta
            seed_ids.append(w["id"])
            print(f"  FOUND: {label} -> {w['id']} (cited_by: {w.get('cited_by_count', 0)})")
        else:
            print(f"  MISS:  {label}")

    for label, query in seed_search.items():
        try:
            data = api_get("works", {"search": query, "per_page": 3})
            results = data.get("results", [])
            if results:
                w = results[0]
                meta = extract_metadata(w)
                meta["source_queries"] = "seed"
                all_works[w["id"]] = meta
                seed_ids.append(w["id"])
                print(f"  FOUND: {label} -> {w['id']} (cited_by: {w.get('cited_by_count', 0)})")
            else:
                print(f"  MISS:  {label}")
        except Exception as e:
            print(f"  ERROR: {label}: {e}")

    print(f"\nSeeds located: {len(seed_ids)}")

    # ----------------------------------------------------------
    # STEP 2: Forward citation snowball from seeds
    # ----------------------------------------------------------
    print("\n" + "=" * 60)
    print("STEP 2: Forward citation snowball from seeds")
    print("=" * 60)

    for sid in seed_ids:
        short = sid.replace("https://openalex.org/", "")
        label = all_works[sid]["authors"].split(";")[0].strip().split()[-1]
        year = all_works[sid]["year"]
        cited_by = all_works[sid]["cited_by_count"]
        print(f"\n  Snowballing from {label} ({year}), cited_by={cited_by}...")

        # Limit snowball to avoid explosion on highly-cited papers
        max_cite = min(300, cited_by) if cited_by else 50
        citing = get_citing_works(sid, max_results=max_cite)
        n_added = add_works(citing, f"snowball_{label}_{year}")
        print(f"    Retrieved {len(citing)} citing works, {n_added} new")

    print(f"\nTotal unique works after snowball: {len(all_works)}")

    # ----------------------------------------------------------
    # STEP 3: Keyword searches (3 queries)
    # ----------------------------------------------------------
    print("\n" + "=" * 60)
    print("STEP 3: Keyword searches")
    print("=" * 60)

    # Q1: Technology x Material Outcomes
    print("\n  Q1: Technology x Material Outcomes")
    q1_works = search_works(
        search_query="material footprint dematerialization decoupling technology innovation",
        filters="publication_year:2000-2026,type:article|review",
        max_results=400
    )
    n1 = add_works(q1_works, "Q1_tech_material")
    print(f"    Q1: {len(q1_works)} retrieved, {n1} new")

    # Q1b: More specific tech indicators
    print("\n  Q1b: Specific tech indicators")
    q1b_works = search_works(
        search_query="material footprint ICT patents R&D economic complexity resource use",
        filters="publication_year:2000-2026,type:article|review",
        max_results=300
    )
    n1b = add_works(q1b_works, "Q1b_tech_specific")
    print(f"    Q1b: {len(q1b_works)} retrieved, {n1b} new")

    # Q2: Geographic displacement / ecologically unequal exchange
    print("\n  Q2: Geographic displacement")
    q2_works = search_works(
        search_query="ecologically unequal exchange material footprint displacement extraction trade",
        filters="publication_year:1990-2026,type:article|review",
        max_results=300
    )
    n2 = add_works(q2_works, "Q2_displacement")
    print(f"    Q2: {len(q2_works)} retrieved, {n2} new")

    # Q3: Theoretical frameworks
    print("\n  Q3: Ecological modernisation + sociology of expectations")
    q3_works = search_works(
        search_query="ecological modernization treadmill production decoupling dematerialization",
        filters="publication_year:1980-2026,type:article|review",
        max_results=300
    )
    n3 = add_works(q3_works, "Q3_frameworks")
    print(f"    Q3: {len(q3_works)} retrieved, {n3} new")

    # Q3b: Sociology of expectations / sociotechnical futures
    print("\n  Q3b: Sociology of expectations + environment")
    q3b_works = search_works(
        search_query="sociology expectations sociotechnical futures green growth imaginary environment",
        filters="publication_year:2000-2026,type:article|review",
        max_results=200
    )
    n3b = add_works(q3b_works, "Q3b_expectations")
    print(f"    Q3b: {len(q3b_works)} retrieved, {n3b} new")

    print(f"\nTotal unique works after all searches: {len(all_works)}")

    # ----------------------------------------------------------
    # STEP 4: Export to CSV
    # ----------------------------------------------------------
    print("\n" + "=" * 60)
    print("STEP 4: Exporting to CSV")
    print("=" * 60)

    # Sort by cited_by_count descending
    sorted_works = sorted(
        all_works.values(),
        key=lambda x: x.get("cited_by_count", 0),
        reverse=True
    )

    csv_headers = [
        "openalex_id", "doi", "title", "year", "authors",
        "author_countries", "author_institutions", "journal",
        "source_type", "work_type", "cited_by_count", "is_oa",
        "topics", "keywords", "source_queries", "abstract"
    ]

    outpath = OUTDIR / "openalex_raw_database.csv"
    with open(outpath, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=csv_headers, extrasaction="ignore")
        writer.writeheader()
        for w in sorted_works:
            writer.writerow(w)

    print(f"  Exported {len(sorted_works)} works to {outpath}")

    # ----------------------------------------------------------
    # STEP 5: Summary statistics
    # ----------------------------------------------------------
    print("\n" + "=" * 60)
    print("STEP 5: Summary statistics")
    print("=" * 60)

    # By year
    year_counts = defaultdict(int)
    for w in sorted_works:
        y = w.get("year", "")
        if y:
            year_counts[y] += 1

    print("\n  Publications by year (top 15):")
    for y, c in sorted(year_counts.items(), reverse=True)[:15]:
        print(f"    {y}: {c}")

    # By country
    country_counts = defaultdict(int)
    for w in sorted_works:
        countries = w.get("author_countries", "")
        for cc in countries.split("; "):
            cc = cc.strip()
            if cc:
                country_counts[cc] += 1

    print("\n  Author countries (top 20):")
    for cc, c in sorted(country_counts.items(), key=lambda x: -x[1])[:20]:
        print(f"    {cc}: {c}")

    # By journal
    journal_counts = defaultdict(int)
    for w in sorted_works:
        j = w.get("journal", "")
        if j:
            journal_counts[j] += 1

    print("\n  Journals (top 20):")
    for j, c in sorted(journal_counts.items(), key=lambda x: -x[1])[:20]:
        print(f"    {j}: {c}")

    # By source query
    query_counts = defaultdict(int)
    for w in sorted_works:
        for q in w.get("source_queries", "").split("; "):
            q = q.strip()
            if q:
                query_counts[q] += 1

    print("\n  Works by source query:")
    for q, c in sorted(query_counts.items(), key=lambda x: -x[1]):
        print(f"    {q}: {c}")

    # Citation stats
    cites = [w.get("cited_by_count", 0) for w in sorted_works]
    print(f"\n  Citation stats:")
    print(f"    Total works: {len(cites)}")
    print(f"    Median citations: {sorted(cites)[len(cites)//2]}")
    print(f"    Mean citations: {sum(cites)/len(cites):.1f}")
    print(f"    Max citations: {max(cites)}")
    print(f"    Works with 50+ citations: {sum(1 for c in cites if c >= 50)}")
    print(f"    Works with 100+ citations: {sum(1 for c in cites if c >= 100)}")

    print("\n  DONE.")


if __name__ == "__main__":
    main()
