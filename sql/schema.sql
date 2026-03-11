-- ================================================================
-- PostgreSQL schema: Sociology Compass literature database
-- "Sociotechnical Futures and Material Realities"
--
-- Usage:
--   createdb sociology_compass
--   cd db && psql -d sociology_compass -f schema.sql
--
-- Tables:
--   works            Core bibliometric data (1 row per paper)
--   authorships      1-to-many: each author + institution + country
--   work_topics      1-to-many: OpenAlex topic classifications
--   work_keywords    1-to-many: author keywords
--   citation_edges   Self-join: which works in our DB cite each other
--   search_provenance  Many-to-many: which queries found each work
--   coding           1-to-1: manual analytical coding (pillars, findings)
-- ================================================================

BEGIN;

-- ── Drop existing tables (reverse dependency order) ───────────
DROP TABLE IF EXISTS coding           CASCADE;
DROP TABLE IF EXISTS search_provenance CASCADE;
DROP TABLE IF EXISTS citation_edges    CASCADE;
DROP TABLE IF EXISTS work_keywords     CASCADE;
DROP TABLE IF EXISTS work_topics       CASCADE;
DROP TABLE IF EXISTS authorships       CASCADE;
DROP TABLE IF EXISTS works             CASCADE;


-- ── 1. works ──────────────────────────────────────────────────
CREATE TABLE works (
    openalex_id    TEXT PRIMARY KEY,
    doi            TEXT,
    title          TEXT,
    year           INTEGER,
    journal        TEXT,
    source_type    TEXT,
    work_type      TEXT,
    cited_by_count INTEGER DEFAULT 0,
    is_oa          BOOLEAN DEFAULT FALSE,
    abstract       TEXT
);

COMMENT ON TABLE works IS 'Core bibliometric record — one row per paper in the review database.';


-- ── 2. authorships ────────────────────────────────────────────
CREATE TABLE authorships (
    id               SERIAL PRIMARY KEY,
    openalex_id      TEXT NOT NULL REFERENCES works(openalex_id) ON DELETE CASCADE,
    author_position  INTEGER,
    author_id        TEXT,
    author_name      TEXT,
    institution_id   TEXT,
    institution_name TEXT,
    country_code     TEXT
);

COMMENT ON TABLE authorships IS 'One row per author × institution. Authors with multiple affiliations get multiple rows.';


-- ── 3. work_topics ────────────────────────────────────────────
CREATE TABLE work_topics (
    id             SERIAL PRIMARY KEY,
    openalex_id    TEXT NOT NULL REFERENCES works(openalex_id) ON DELETE CASCADE,
    topic_id       TEXT,
    topic_name     TEXT,
    subfield_name  TEXT,
    field_name     TEXT,
    domain_name    TEXT,
    score          REAL DEFAULT 0
);

COMMENT ON TABLE work_topics IS 'OpenAlex topic classifications (top 5 per work) with confidence scores.';


-- ── 4. work_keywords ──────────────────────────────────────────
CREATE TABLE work_keywords (
    id          SERIAL PRIMARY KEY,
    openalex_id TEXT NOT NULL REFERENCES works(openalex_id) ON DELETE CASCADE,
    keyword     TEXT
);

COMMENT ON TABLE work_keywords IS 'Author-supplied keywords, one per row.';


-- ── 5. citation_edges ─────────────────────────────────────────
CREATE TABLE citation_edges (
    citing_id TEXT NOT NULL REFERENCES works(openalex_id) ON DELETE CASCADE,
    cited_id  TEXT NOT NULL REFERENCES works(openalex_id) ON DELETE CASCADE,
    PRIMARY KEY (citing_id, cited_id)
);

COMMENT ON TABLE citation_edges IS 'Intra-database citation network: which works in our DB cite which other works in our DB.';


-- ── 6. search_provenance ──────────────────────────────────────
CREATE TABLE search_provenance (
    openalex_id TEXT NOT NULL REFERENCES works(openalex_id) ON DELETE CASCADE,
    query_label TEXT NOT NULL,
    PRIMARY KEY (openalex_id, query_label)
);

COMMENT ON TABLE search_provenance IS 'Many-to-many: which search queries (seed, snowball_*, Q1-Q3b, S1-S6) found each work.';


-- ── 7. coding ─────────────────────────────────────────────────
CREATE TABLE coding (
    openalex_id         TEXT PRIMARY KEY REFERENCES works(openalex_id) ON DELETE CASCADE,
    abstract_pillar     TEXT,   -- P1..P6 (which abstract pillar?)
    theoretical_frame   TEXT,   -- ecological_mod | treadmill | world_systems | STIRPAT | expectations | degrowth | none
    tech_indicator      TEXT,   -- R&D | patents | ICT | ECI | software | none
    finding_tech        TEXT,   -- positive | negative | null | mediated_by_affluence
    finding_affluence   TEXT,   -- positive | negative | null | not_tested
    displacement        TEXT,   -- yes | no | not_tested
    supports_decoupling TEXT,   -- yes | partial_relative | no
    section_relevance   TEXT,   -- article section(s) where this work is cited
    include_final       TEXT,   -- yes | no | maybe
    notes               TEXT
);

COMMENT ON TABLE coding IS 'Manual analytical coding — empty template, fill during close reading.';
COMMENT ON COLUMN coding.abstract_pillar IS 'P1=tech indicators, P2=affluence, P3=displacement, P4=EMT debate, P5=expectations, P6=competing visions';


-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX idx_works_year         ON works(year);
CREATE INDEX idx_works_journal      ON works(journal);
CREATE INDEX idx_works_cited        ON works(cited_by_count DESC);

CREATE INDEX idx_auth_work          ON authorships(openalex_id);
CREATE INDEX idx_auth_country       ON authorships(country_code);
CREATE INDEX idx_auth_author        ON authorships(author_id);
CREATE INDEX idx_auth_institution   ON authorships(institution_id);

CREATE INDEX idx_topics_work        ON work_topics(openalex_id);
CREATE INDEX idx_topics_field       ON work_topics(field_name);
CREATE INDEX idx_topics_domain      ON work_topics(domain_name);

CREATE INDEX idx_kw_work            ON work_keywords(openalex_id);
CREATE INDEX idx_kw_keyword         ON work_keywords(keyword);

CREATE INDEX idx_cite_citing        ON citation_edges(citing_id);
CREATE INDEX idx_cite_cited         ON citation_edges(cited_id);

CREATE INDEX idx_prov_work          ON search_provenance(openalex_id);
CREATE INDEX idx_prov_query         ON search_provenance(query_label);

CREATE INDEX idx_coding_pillar      ON coding(abstract_pillar);
CREATE INDEX idx_coding_frame       ON coding(theoretical_frame);
CREATE INDEX idx_coding_include     ON coding(include_final);


-- ── Load data from CSVs ───────────────────────────────────────
-- Run from inside the db/ directory:  psql -d sociology_compass -f schema.sql

\copy works FROM 'works.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy authorships(openalex_id, author_position, author_id, author_name, institution_id, institution_name, country_code) FROM 'authorships.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy work_topics(openalex_id, topic_id, topic_name, subfield_name, field_name, domain_name, score) FROM 'work_topics.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy work_keywords(openalex_id, keyword) FROM 'work_keywords.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy citation_edges FROM 'citation_edges.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy search_provenance FROM 'search_provenance.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\copy coding FROM 'coding.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');


-- ── Reset sequences after COPY ────────────────────────────────
SELECT setval('authorships_id_seq',  (SELECT COALESCE(MAX(id), 0) + 1 FROM authorships));
SELECT setval('work_topics_id_seq',  (SELECT COALESCE(MAX(id), 0) + 1 FROM work_topics));
SELECT setval('work_keywords_id_seq',(SELECT COALESCE(MAX(id), 0) + 1 FROM work_keywords));


-- ── Verification counts ───────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '──────────────────────────────────────';
    RAISE NOTICE 'Schema loaded.  Row counts:';
    RAISE NOTICE '  works:            %', (SELECT COUNT(*) FROM works);
    RAISE NOTICE '  authorships:      %', (SELECT COUNT(*) FROM authorships);
    RAISE NOTICE '  work_topics:      %', (SELECT COUNT(*) FROM work_topics);
    RAISE NOTICE '  work_keywords:    %', (SELECT COUNT(*) FROM work_keywords);
    RAISE NOTICE '  citation_edges:   %', (SELECT COUNT(*) FROM citation_edges);
    RAISE NOTICE '  search_provenance:%', (SELECT COUNT(*) FROM search_provenance);
    RAISE NOTICE '  coding:           %', (SELECT COUNT(*) FROM coding);
    RAISE NOTICE '──────────────────────────────────────';
END $$;

COMMIT;
