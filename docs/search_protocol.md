# Search Protocol — Structured Evidence Review

**Article**: "Sociotechnical Futures and Material Realities"
**Journal**: Sociology Compass
**Date**: March 2026

---

## 1. Search Strategy Overview

Three complementary queries covering the three pillars of the review:

| Query | Focus | Expected role in article |
|-------|-------|--------------------------|
| Q1 | Technology indicators × material outcomes | §3.1 + §3.2 (core evidence) |
| Q2 | Geographic displacement / ecologically unequal exchange | §3.3 (displacement channel) |
| Q3 | Theoretical frameworks (ecological modernisation, sociology of expectations) | §2 (framework) + §4 (discussion) |

**Period**: 1980–2026 (core: 2000–2026; foundational pre-2000 captured via Q3)
**Languages**: English

---

## 2. Web of Science (Core Collection)

Access: https://www.webofscience.com
Field tag: `TS=` searches title, abstract, author keywords, Keywords Plus.
Wildcards: `*` (right truncation, min 3 chars before wildcard).
Export: mark all → Export → select "Full Record" → Tab delimited or BibTeX.

### Q1 — Technology × Material Outcomes (core query)

```
TS=("material footprint" OR "material flow*" OR "domestic material consumption"
    OR "resource consumption" OR "resource use" OR demateriali* OR decoupling
    OR "ecological footprint")
AND
TS=(technolog* OR ICT OR digital* OR innovat* OR "R&D" OR patent*
    OR "economic complexity" OR "software complexity" OR "information and communication")
AND
TS=(countr* OR nation* OR econom* OR cross-national OR panel OR global OR OECD
    OR "European Union" OR develop*)
```

**Refine by**: Document Types = Article OR Review
**Expected**: ~150–300 results

### Q2 — Geographic Displacement

```
TS=("ecologically unequal exchange" OR "material footprint" OR "resource extraction"
    OR "embodied material*" OR "raw material equivalents")
AND
TS=(displac* OR transfer* OR trade OR "embodied resource*" OR outsourc*
    OR "supply chain" OR footprint*)
AND
TS=(affluen* OR income OR GDP OR wealth OR "high-income" OR "low-income"
    OR North-South OR asymmetr*)
```

**Expected**: ~80–150 results

### Q3 — Theoretical Frameworks

```
TS=("ecological moderni*" OR "treadmill of production" OR "sociology of expectations"
    OR "sociotechnical imaginar*" OR "sociotechnical future*" OR "green growth"
    OR "techno-optimis*")
AND
TS=(demateriali* OR decoupling OR "material footprint" OR "resource*"
    OR environment* OR sustainab*)
```

**Expected**: ~100–200 results

### WoS Export Settings
- Format: **BibTeX** (for easy import into reference managers) or **Tab-delimited** (for spreadsheet work)
- Fields: Full Record (title, authors, abstract, keywords, journal, year, DOI, cited references, times cited)
- Sort by: Times Cited (descending) — helps identify high-impact studies first

---

## 3. Scopus

Access: https://www.scopus.com
Field code: `TITLE-ABS-KEY()` searches title, abstract, and author keywords.
Wildcards: `*` (right truncation), `?` (single character).
**Important**: parentheses are mandatory around field code arguments.
Export: Select all → Export → CSV or BibTeX; max 2,000 per export.

### Q1 — Technology × Material Outcomes

```
TITLE-ABS-KEY("material footprint" OR "material flow*" OR "domestic material consumption"
    OR "resource consumption" OR demateriali* OR decoupling OR "ecological footprint")
AND
TITLE-ABS-KEY(technolog* OR ICT OR digital* OR innovat* OR "R&D" OR patent*
    OR "economic complexity" OR "software complexity")
AND
TITLE-ABS-KEY(countr* OR nation* OR econom* OR "cross-national" OR panel OR global)
AND
(LIMIT-TO(DOCTYPE, "ar") OR LIMIT-TO(DOCTYPE, "re"))
AND
(LIMIT-TO(LANGUAGE, "English"))
```

### Q2 — Geographic Displacement

```
TITLE-ABS-KEY("ecologically unequal exchange" OR "material footprint" OR "embodied material*"
    OR "raw material equivalents")
AND
TITLE-ABS-KEY(displac* OR transfer* OR trade OR outsourc* OR "supply chain" OR footprint*)
AND
TITLE-ABS-KEY(affluen* OR income OR GDP OR wealth OR asymmetr* OR "North-South")
AND
(LIMIT-TO(DOCTYPE, "ar") OR LIMIT-TO(DOCTYPE, "re"))
```

### Q3 — Theoretical Frameworks

```
TITLE-ABS-KEY("ecological moderni*" OR "treadmill of production" OR "sociology of expectations"
    OR "sociotechnical imaginar*" OR "green growth" OR "techno-optimis*")
AND
TITLE-ABS-KEY(demateriali* OR decoupling OR "material footprint" OR environment* OR sustainab*)
AND
(LIMIT-TO(DOCTYPE, "ar") OR LIMIT-TO(DOCTYPE, "re"))
```

### Scopus Export Settings
- Format: **CSV** (includes abstract, keywords, cited-by count, DOI)
- Fields: Citation information + Abstract + Keywords + Funding details
- Sort by: Cited by (descending)

---

## 4. Google Scholar

Access: https://scholar.google.com
**Role**: Supplementary. Captures grey literature (reports, working papers, theses) missed by WoS/Scopus.
**Limitations**: No field tags, limited Boolean, max ~1,000 visible results, IP block after ~180 queries.
**Strategy**: Title searches + known-item searches. Review first 200 results per query.

### Known Grey Literature Items (search by title)

```
allintitle: "Decoupling Debunked"
allintitle: "The Power of the Machine"
allintitle: "resource efficiency" "green growth" UNEP
allintitle: "global material flows" "resource productivity" UNEP
allintitle: "material footprint" "sustainable development goals"
allintitle: "circular economy" "material footprint" European Commission
```

### Targeted Searches

```
"material footprint" technology dematerialization evidence site:unep.org
"material footprint" "decoupling" report site:oecd.org
"resource efficiency" "green growth" site:ec.europa.eu
"dematerialization" technology "working paper"
```

### Google Scholar Tips
- Use **Publish or Perish** software (Harzing) for batch export from Google Scholar → avoids IP blocks
- Export as BibTeX or RIS
- Focus on the first 200 results per query (ordered by relevance/citations)
- Flag grey literature items with `type = report` in the database

---

## 5. Deduplication Procedure

After exporting from all three databases:

1. Import all records into a single spreadsheet or reference manager (Zotero recommended)
2. Deduplicate by DOI (primary) and title fuzzy match (secondary)
3. Expected overlap: ~40–60% between WoS and Scopus; ~20% with Google Scholar unique additions
4. Expected unique records after deduplication: **200–350 total candidates**
5. Screen by title + abstract → **60–80 relevant studies**
6. Full-text coding → **40–60 studies** in final database

---

## 6. PRISMA-like Flow (for transparency, not publication)

All searches were executed via OpenAlex API (see §7). WoS/Scopus query syntax in §§2–3 is retained as reference; OpenAlex replicated the same Boolean logic programmatically.

```
OpenAlex structured queries (Q1–S6):  2,655
Citation snowball (9 seeds):          2,415
Seeds:                                    9
                    ↓
Total records:                        5,079
After deduplication (by OpenAlex ID): 4,465
                    ↓
Title/abstract screening:             4,465
Excluded (not relevant):              4,315
                    ↓
Full-text assessment:                   150
Excluded (no cross-national data /
  single-sector / no tech indicator):   120
                    ↓
Final included studies:                  30
```

Note: Sociology Compass does not require a PRISMA diagram for review articles, but maintaining this flow ensures rigour and is useful if reviewers ask about search completeness. Raw provenance data are deposited in the public repository (see Data Availability).

---

## 7. OpenAlex API (primary execution platform)

All searches were executed programmatically via the OpenAlex API, which indexes >250 million works and provides coverage comparable to WoS and Scopus for peer-reviewed literature. The Boolean logic from the WoS/Scopus queries (§§2–3) was replicated as OpenAlex concept and keyword filters.

- **Structured queries** (Q1, Q1b, Q2, Q3, Q3b, S1–S6): 12 queries returning 2,655 records
- **Citation snowball** (forward + backward from 9 seed papers): 2,415 records
- **Deduplication**: by OpenAlex ID, yielding 4,465 unique works
- **Scoring and ranking**: composite score based on citation count, pillar coverage, internal citations, and seed proximity
- Script: `openalex_search.py`; provenance log: `db/search_provenance.csv`

---

## 8. Access Notes

- **WoS**: Available via CONICET institutional access (portal BDU / Biblioteca Electrónica MinCyT)
- **Scopus**: Available via CONICET institutional access (same portal) OR via University of Porto (letras.up.pt credentials)
- **Google Scholar**: Open access, no credentials needed
- **OpenAlex**: Free API key required since Feb 2026 (register at openalex.org)
