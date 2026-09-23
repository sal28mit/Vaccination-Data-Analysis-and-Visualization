-- ============================================================================
-- schema.sql
-- Normalized SQL schema for the Vaccination Data Analysis project.
-- Designed as star-schema-ish: dimension tables (country, disease, vaccine)
-- + fact tables (coverage, incidence, cases, introduction, schedule).
-- Compatible with SQLite (used by 03_create_database.py) and easily portable
-- to MySQL/Postgres/SQL Server (adjust AUTOINCREMENT / TEXT types as needed).
-- ============================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS fact_vaccine_schedule;
DROP TABLE IF EXISTS fact_vaccine_introduction;
DROP TABLE IF EXISTS fact_reported_cases;
DROP TABLE IF EXISTS fact_incidence;
DROP TABLE IF EXISTS fact_coverage;
DROP TABLE IF EXISTS dim_vaccine;
DROP TABLE IF EXISTS dim_disease;
DROP TABLE IF EXISTS dim_country;

-- ----------------------------------------------------------------------------
-- Dimension: Country
-- ----------------------------------------------------------------------------
CREATE TABLE dim_country (
    country_code    TEXT PRIMARY KEY,      -- ISO Alpha-3 code
    country_name    TEXT NOT NULL,
    who_region      TEXT
);

-- ----------------------------------------------------------------------------
-- Dimension: Disease
-- ----------------------------------------------------------------------------
CREATE TABLE dim_disease (
    disease_code        TEXT PRIMARY KEY,
    disease_description  TEXT
);

-- ----------------------------------------------------------------------------
-- Dimension: Vaccine / Antigen
-- ----------------------------------------------------------------------------
CREATE TABLE dim_vaccine (
    vaccine_code         TEXT PRIMARY KEY,   -- antigen code
    vaccine_description  TEXT
);

-- ----------------------------------------------------------------------------
-- Fact: Coverage  (Table 1 in the brief)
-- ----------------------------------------------------------------------------
CREATE TABLE fact_coverage (
    coverage_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    country_code           TEXT NOT NULL REFERENCES dim_country(country_code),
    year                    INTEGER NOT NULL,
    vaccine_code            TEXT NOT NULL REFERENCES dim_vaccine(vaccine_code),
    coverage_category       TEXT NOT NULL,      -- ADMIN / OFFICIAL / WUENIC
    coverage_category_desc  TEXT,
    target_number           INTEGER,
    doses                   INTEGER,
    coverage_pct            REAL CHECK (coverage_pct BETWEEN 0 AND 100)
);
CREATE INDEX idx_coverage_country_year ON fact_coverage(country_code, year);
CREATE INDEX idx_coverage_vaccine ON fact_coverage(vaccine_code);

-- ----------------------------------------------------------------------------
-- Fact: Incidence Rate  (Table 2 in the brief)
-- ----------------------------------------------------------------------------
CREATE TABLE fact_incidence (
    incidence_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    country_code      TEXT NOT NULL REFERENCES dim_country(country_code),
    year               INTEGER NOT NULL,
    disease_code       TEXT NOT NULL REFERENCES dim_disease(disease_code),
    denominator         TEXT,        -- e.g. per 100,000 population
    incidence_rate      REAL CHECK (incidence_rate >= 0)
);
CREATE INDEX idx_incidence_country_year ON fact_incidence(country_code, year);
CREATE INDEX idx_incidence_disease ON fact_incidence(disease_code);

-- ----------------------------------------------------------------------------
-- Fact: Reported Cases  (Table 3 in the brief)
-- ----------------------------------------------------------------------------
CREATE TABLE fact_reported_cases (
    case_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    country_code    TEXT NOT NULL REFERENCES dim_country(country_code),
    year             INTEGER NOT NULL,
    disease_code     TEXT NOT NULL REFERENCES dim_disease(disease_code),
    cases             INTEGER CHECK (cases >= 0)
);
CREATE INDEX idx_cases_country_year ON fact_reported_cases(country_code, year);
CREATE INDEX idx_cases_disease ON fact_reported_cases(disease_code);

-- ----------------------------------------------------------------------------
-- Fact: Vaccine Introduction  (Table 4 in the brief)
-- ----------------------------------------------------------------------------
CREATE TABLE fact_vaccine_introduction (
    intro_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    country_code     TEXT NOT NULL REFERENCES dim_country(country_code),
    who_region        TEXT,
    year               INTEGER NOT NULL,
    vaccine_description TEXT,
    introduced          INTEGER CHECK (introduced IN (0,1))  -- boolean
);
CREATE INDEX idx_intro_country_year ON fact_vaccine_introduction(country_code, year);

-- ----------------------------------------------------------------------------
-- Fact: Vaccine Schedule  (Table 5 in the brief)
-- ----------------------------------------------------------------------------
CREATE TABLE fact_vaccine_schedule (
    schedule_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    country_code           TEXT NOT NULL REFERENCES dim_country(country_code),
    who_region               TEXT,
    year                      INTEGER NOT NULL,
    vaccine_code              TEXT REFERENCES dim_vaccine(vaccine_code),
    schedule_rounds           INTEGER,
    target_pop                TEXT,
    target_pop_description    TEXT,
    geoarea                    TEXT,
    age_administered           TEXT,
    source_comment              TEXT
);
CREATE INDEX idx_schedule_country_year ON fact_vaccine_schedule(country_code, year);
