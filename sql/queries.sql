-- ================================================================
-- Analytical queries — Sociology Compass literature database
-- "Sociotechnical Futures and Material Realities"
--
-- Usage:
--   psql -d sociology_compass -f queries.sql
--
-- Sections:
--   A. DATA-READY queries (work with raw imported data)
--   B. CODING-DEPENDENT queries (require manual coding in coding table)
-- ================================================================

\echo ''
\echo '================================================================'
\echo 'A. DATA-READY QUERIES (no manual coding needed)'
\echo '================================================================'


-- ── A1. Geography of knowledge production ─────────────────────
\echo ''
\echo '── A1. Geography of knowledge production by region ──'

WITH country_papers AS (
    SELECT DISTINCT a.country_code, a.openalex_id
    FROM authorships a
    WHERE a.country_code != ''
),
region_map AS (
    SELECT
        country_code,
        CASE
            WHEN country_code IN ('US','GB','DE','SE','NL','AU','CA','AT','NO',
                                  'CH','FI','FR','DK','BE','IE','IT','ES','PT',
                                  'JP','NZ','IS','LU')
                THEN 'Global North'
            WHEN country_code IN ('CN','BR','RU','IN','ZA')
                THEN 'BRICS'
            WHEN country_code IN ('AR','MX','CL','CO','PE','EC','UY','PY',
                                  'BO','VE','CR','PA','CU','DO')
                THEN 'Latin America'
            WHEN country_code IN ('NG','KE','GH','ET','TZ','UG','ZW','CM',
                                  'SN','CI','MA','DZ','TN','EG','MW','MZ')
                THEN 'Africa'
            ELSE 'Other'
        END AS region
    FROM country_papers
)
SELECT
    r.region,
    COUNT(DISTINCT cp.openalex_id) AS papers,
    ROUND(100.0 * COUNT(DISTINCT cp.openalex_id) /
          (SELECT COUNT(DISTINCT openalex_id) FROM country_papers), 1) AS pct
FROM country_papers cp
JOIN region_map r ON cp.country_code = r.country_code
GROUP BY r.region
ORDER BY papers DESC;


-- ── A2. Top 25 author countries ───────────────────────────────
\echo ''
\echo '── A2. Top 25 author countries ──'

SELECT
    a.country_code,
    COUNT(DISTINCT a.openalex_id) AS papers,
    COUNT(DISTINCT a.author_id) AS unique_authors
FROM authorships a
WHERE a.country_code != ''
GROUP BY a.country_code
ORDER BY papers DESC
LIMIT 25;


-- ── A3. Discipline distribution (journals) ────────────────────
\echo ''
\echo '── A3. Discipline distribution (top 30 journals) ──'

SELECT
    w.journal,
    COUNT(*) AS papers,
    ROUND(AVG(w.cited_by_count), 0) AS avg_cites,
    MIN(w.year) AS earliest,
    MAX(w.year) AS latest
FROM works w
WHERE w.journal != ''
GROUP BY w.journal
ORDER BY papers DESC
LIMIT 30;


-- ── A4. Disciplinary clusters (approximate) ──────────────────
\echo ''
\echo '── A4. Disciplinary clusters ──'

SELECT
    CASE
        WHEN journal IN ('Environmental Sociology','Organization & Environment',
                         'Society & Natural Resources','Sociology',
                         'American Journal of Sociology','Annual Review of Sociology',
                         'Social Forces','Social Problems','American Sociological Review',
                         'Sociology Compass','Journal of World-Systems Research')
            THEN 'Environmental Sociology'
        WHEN journal IN ('Journal of Industrial Ecology','Journal of Cleaner Production',
                         'Resources Conservation and Recycling','Ecological Economics',
                         'Sustainable Production and Consumption',
                         'Environmental Research Letters','Environmental Science & Technology',
                         'Global Environmental Change')
            THEN 'Industrial Ecology / Ecol.Econ.'
        WHEN journal IN ('Energy Research & Social Science','Energy Policy',
                         'Technological Forecasting and Social Change',
                         'Energies','Energy','Renewable and Sustainable Energy Reviews')
            THEN 'Energy / Technology'
        WHEN journal IN ('Sustainability','Sustainability Science',
                         'Sustainable Development',
                         'Environmental Science and Pollution Research')
            THEN 'Sustainability (general)'
        WHEN journal IN ('Journal of Political Ecology','Environmental Politics',
                         'Geoforum','Antipode','Environment and Planning E')
            THEN 'Political Ecology / Env.Politics'
        ELSE 'Other'
    END AS discipline,
    COUNT(*) AS papers,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM works), 1) AS pct
FROM works
WHERE journal != ''
GROUP BY discipline
ORDER BY papers DESC;


-- ── A5. Temporal distribution ─────────────────────────────────
\echo ''
\echo '── A5. Publications by year (2000-2026) ──'

SELECT
    w.year,
    COUNT(*) AS papers,
    REPEAT('#', (COUNT(*)::int / 10)) AS bar
FROM works w
WHERE w.year BETWEEN 2000 AND 2026
GROUP BY w.year
ORDER BY w.year;


-- ── A6. Top 50 most-cited papers ──────────────────────────────
\echo ''
\echo '── A6. Top 50 most-cited papers in the database ──'

SELECT
    w.year,
    LEFT(w.title, 80) AS title,
    w.cited_by_count,
    w.journal,
    (SELECT string_agg(DISTINCT a.author_name, '; ' ORDER BY a.author_name)
     FROM authorships a
     WHERE a.openalex_id = w.openalex_id
       AND a.author_position = 0) AS first_author
FROM works w
ORDER BY w.cited_by_count DESC
LIMIT 50;


-- ── A7. OpenAlex topic distribution (field level) ─────────────
\echo ''
\echo '── A7. Topic distribution by OpenAlex field ──'

SELECT
    t.field_name,
    COUNT(DISTINCT t.openalex_id) AS papers,
    ROUND(100.0 * COUNT(DISTINCT t.openalex_id) /
          (SELECT COUNT(*) FROM works), 1) AS pct
FROM work_topics t
WHERE t.field_name != ''
GROUP BY t.field_name
ORDER BY papers DESC
LIMIT 20;


-- ── A8. Top 40 keywords ──────────────────────────────────────
\echo ''
\echo '── A8. Top 40 keywords ──'

SELECT
    LOWER(k.keyword) AS keyword,
    COUNT(*) AS freq
FROM work_keywords k
GROUP BY LOWER(k.keyword)
ORDER BY freq DESC
LIMIT 40;


-- ── A9. Search provenance breakdown ───────────────────────────
\echo ''
\echo '── A9. Works by search query (provenance) ──'

SELECT
    sp.query_label,
    COUNT(DISTINCT sp.openalex_id) AS works
FROM search_provenance sp
GROUP BY sp.query_label
ORDER BY works DESC;


-- ── A10. Citation network summary ─────────────────────────────
\echo ''
\echo '── A10. Citation network (intra-database) ──'

SELECT
    COUNT(*) AS total_edges,
    COUNT(DISTINCT citing_id) AS works_that_cite,
    COUNT(DISTINCT cited_id)  AS works_that_are_cited
FROM citation_edges;


-- ── A11. Most-cited within the database ───────────────────────
\echo ''
\echo '── A11. Most-cited works (internal citations) ──'

SELECT
    ce.cited_id,
    COUNT(*) AS internal_cites,
    w.year,
    LEFT(w.title, 70) AS title,
    w.journal
FROM citation_edges ce
JOIN works w ON w.openalex_id = ce.cited_id
GROUP BY ce.cited_id, w.year, w.title, w.journal
ORDER BY internal_cites DESC
LIMIT 30;


-- ── A12. Works citing the most other works in our DB ──────────
\echo ''
\echo '── A12. Works with most internal references ──'

SELECT
    ce.citing_id,
    COUNT(*) AS internal_refs,
    w.year,
    LEFT(w.title, 70) AS title
FROM citation_edges ce
JOIN works w ON w.openalex_id = ce.citing_id
GROUP BY ce.citing_id, w.year, w.title
ORDER BY internal_refs DESC
LIMIT 20;


-- ── A13. North-South mismatch ─────────────────────────────────
\echo ''
\echo '── A13. North-South mismatch (author geography vs Global South mentions) ──'

WITH author_regions AS (
    SELECT DISTINCT
        a.openalex_id,
        CASE
            WHEN a.country_code IN ('US','GB','DE','SE','NL','AU','CA','AT','NO',
                                    'CH','FI','FR','DK','BE','IE','IT','ES','PT',
                                    'JP','NZ','IS','LU')
                THEN 'North'
            ELSE 'South'
        END AS author_loc
    FROM authorships a
    WHERE a.country_code != ''
),
text_mentions AS (
    SELECT
        w.openalex_id,
        CASE
            WHEN LOWER(w.abstract || ' ' || w.title) ~
                 'africa|latin america|south america|india|indonesia|bangladesh|vietnam|philippines|brazil|argentina|mexico|chile|colombia|peru|mercosur|china|chinese|middle east|iran|turkey'
                THEN TRUE
            ELSE FALSE
        END AS mentions_south
    FROM works w
)
SELECT
    CASE WHEN ar.author_loc = 'North' THEN 'Authors from North'
         ELSE 'Authors from South' END AS group_label,
    COUNT(DISTINCT ar.openalex_id) AS total_papers,
    COUNT(DISTINCT ar.openalex_id) FILTER (WHERE tm.mentions_south)
        AS mention_global_south,
    ROUND(100.0 * COUNT(DISTINCT ar.openalex_id) FILTER (WHERE tm.mentions_south)
          / NULLIF(COUNT(DISTINCT ar.openalex_id), 0), 1) AS pct_mention_south
FROM author_regions ar
JOIN text_mentions tm ON ar.openalex_id = tm.openalex_id
GROUP BY ar.author_loc
ORDER BY total_papers DESC;


-- ── A14. Co-authorship: international collaboration rate ──────
\echo ''
\echo '── A14. International collaboration rate by year ──'

WITH paper_countries AS (
    SELECT
        a.openalex_id,
        COUNT(DISTINCT a.country_code) AS n_countries
    FROM authorships a
    WHERE a.country_code != ''
    GROUP BY a.openalex_id
)
SELECT
    w.year,
    COUNT(*) AS papers,
    COUNT(*) FILTER (WHERE pc.n_countries > 1) AS intl_collab,
    ROUND(100.0 * COUNT(*) FILTER (WHERE pc.n_countries > 1) /
          NULLIF(COUNT(*), 0), 1) AS pct_intl
FROM works w
JOIN paper_countries pc ON w.openalex_id = pc.openalex_id
WHERE w.year BETWEEN 2000 AND 2026
GROUP BY w.year
ORDER BY w.year;


-- ── A15. Gap search yield (new S1-S6 vs original) ────────────
\echo ''
\echo '── A15. Gap search yield (S1-S6 vs original queries) ──'

SELECT
    CASE
        WHEN sp.query_label LIKE 'S%' THEN 'New (S1-S6)'
        ELSE 'Original (seed/snowball/Q1-Q3b)'
    END AS search_generation,
    COUNT(DISTINCT sp.openalex_id) AS works
FROM search_provenance sp
GROUP BY search_generation;


-- ── A16. Works found by multiple queries (overlap) ────────────
\echo ''
\echo '── A16. Multi-query overlap (works found by N queries) ──'

SELECT
    n_queries,
    COUNT(*) AS works
FROM (
    SELECT openalex_id, COUNT(DISTINCT query_label) AS n_queries
    FROM search_provenance
    GROUP BY openalex_id
) sub
GROUP BY n_queries
ORDER BY n_queries;


\echo ''
\echo '================================================================'
\echo 'B. CODING-DEPENDENT QUERIES'
\echo '    (require manual coding in the coding table)'
\echo '    These will return empty until coding is populated.'
\echo '================================================================'


-- ── B1. Temporal trajectory by theoretical camp ───────────────
\echo ''
\echo '── B1. Temporal trajectory by theoretical framework ──'

SELECT
    w.year,
    c.theoretical_frame,
    COUNT(*) AS papers
FROM coding c
JOIN works w ON w.openalex_id = c.openalex_id
WHERE c.theoretical_frame != '' AND c.theoretical_frame IS NOT NULL
  AND c.include_final = 'yes'
GROUP BY w.year, c.theoretical_frame
ORDER BY w.year, c.theoretical_frame;


-- ── B2. Most-cited papers per abstract pillar ─────────────────
\echo ''
\echo '── B2. Most-cited papers per abstract pillar ──'

SELECT
    c.abstract_pillar,
    w.year,
    LEFT(w.title, 70) AS title,
    w.cited_by_count,
    w.journal
FROM coding c
JOIN works w ON w.openalex_id = c.openalex_id
WHERE c.abstract_pillar != '' AND c.abstract_pillar IS NOT NULL
  AND c.include_final = 'yes'
ORDER BY c.abstract_pillar, w.cited_by_count DESC;


-- ── B3. Vote-counting by technology indicator type ────────────
\echo ''
\echo '── B3. Vote-counting: technology indicator → finding ──'

SELECT
    c.tech_indicator,
    c.finding_tech,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY c.tech_indicator), 1)
        AS pct_within_indicator
FROM coding c
WHERE c.tech_indicator != '' AND c.tech_indicator IS NOT NULL
  AND c.finding_tech != '' AND c.finding_tech IS NOT NULL
  AND c.include_final = 'yes'
GROUP BY c.tech_indicator, c.finding_tech
ORDER BY c.tech_indicator, n DESC;


-- ── B4. Displacement studies: author country vs extraction ────
\echo ''
\echo '── B4. Are displacement studies written from consuming or extracting countries? ──'

WITH displacement_authors AS (
    SELECT DISTINCT
        c.openalex_id,
        a.country_code,
        CASE
            WHEN a.country_code IN ('US','GB','DE','SE','NL','AU','CA','AT','NO',
                                    'CH','FI','FR','DK','BE','IE','IT','ES','PT',
                                    'JP','NZ','IS','LU')
                THEN 'Net importer (North)'
            WHEN a.country_code IN ('CN','BR','IN','RU','ZA','CL','PE','ID',
                                    'PH','MX','CO','AR')
                THEN 'Net exporter (South)'
            ELSE 'Other'
        END AS trade_position
    FROM coding c
    JOIN authorships a ON a.openalex_id = c.openalex_id
    WHERE c.displacement = 'yes'
      AND a.country_code != ''
      AND c.include_final = 'yes'
)
SELECT
    trade_position,
    COUNT(DISTINCT openalex_id) AS papers,
    COUNT(DISTINCT country_code) AS unique_countries
FROM displacement_authors
GROUP BY trade_position
ORDER BY papers DESC;


-- ── B5. Citation density between theoretical camps ────────────
\echo ''
\echo '── B5. Citation density between theoretical camps ──'

SELECT
    c_citing.theoretical_frame AS citing_camp,
    c_cited.theoretical_frame  AS cited_camp,
    COUNT(*) AS edges
FROM citation_edges ce
JOIN coding c_citing ON c_citing.openalex_id = ce.citing_id
JOIN coding c_cited  ON c_cited.openalex_id  = ce.cited_id
WHERE c_citing.theoretical_frame != '' AND c_citing.theoretical_frame IS NOT NULL
  AND c_cited.theoretical_frame  != '' AND c_cited.theoretical_frame  IS NOT NULL
  AND c_citing.include_final = 'yes'
  AND c_cited.include_final  = 'yes'
GROUP BY c_citing.theoretical_frame, c_cited.theoretical_frame
ORDER BY edges DESC;


-- ── B6. Country × theoretical frame (who argues what?) ────────
\echo ''
\echo '── B6. Geography of arguments: country × theoretical frame ──'

SELECT
    a.country_code,
    c.theoretical_frame,
    COUNT(DISTINCT c.openalex_id) AS papers
FROM coding c
JOIN authorships a ON a.openalex_id = c.openalex_id
WHERE c.theoretical_frame != '' AND c.theoretical_frame IS NOT NULL
  AND a.country_code != ''
  AND c.include_final = 'yes'
GROUP BY a.country_code, c.theoretical_frame
HAVING COUNT(DISTINCT c.openalex_id) >= 3
ORDER BY a.country_code, papers DESC;


-- ── B7. Decoupling evidence summary ──────────────────────────
\echo ''
\echo '── B7. Decoupling evidence: vote count ──'

SELECT
    c.supports_decoupling,
    COUNT(*) AS papers,
    ROUND(AVG(w.cited_by_count), 0) AS avg_cites,
    ROUND(100.0 * COUNT(*) /
          NULLIF((SELECT COUNT(*) FROM coding WHERE supports_decoupling != ''
                  AND supports_decoupling IS NOT NULL AND include_final = 'yes'), 0),
          1) AS pct
FROM coding c
JOIN works w ON w.openalex_id = c.openalex_id
WHERE c.supports_decoupling != '' AND c.supports_decoupling IS NOT NULL
  AND c.include_final = 'yes'
GROUP BY c.supports_decoupling
ORDER BY papers DESC;


-- ── B8. Section allocation check ─────────────────────────────
\echo ''
\echo '── B8. Papers allocated per article section ──'

SELECT
    UNNEST(string_to_array(c.section_relevance, ';')) AS section,
    COUNT(*) AS papers
FROM coding c
WHERE c.section_relevance != '' AND c.section_relevance IS NOT NULL
  AND c.include_final = 'yes'
GROUP BY section
ORDER BY section;


\echo ''
\echo 'Queries complete.'
