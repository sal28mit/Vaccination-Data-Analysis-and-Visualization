-- ============================================================================
-- analysis_queries.sql
-- Answers a selection of the "Questions to be answered" from the project
-- brief, directly against the normalized schema. Use these as-is in a SQL
-- client, or paste into Power BI's "Get Data -> SQL Server/ODBC -> Advanced
-- query" to build visuals straight from the source.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- EASY Q1 & Q9: How do vaccination rates correlate with a decrease in
-- disease incidence? (country/year level average coverage vs avg incidence)
-- ---------------------------------------------------------------------------
SELECT
    c.country_code,
    c.year,
    ROUND(AVG(c.coverage_pct), 1)  AS avg_coverage_pct,
    ROUND(AVG(i.incidence_rate), 2) AS avg_incidence_rate
FROM fact_coverage c
JOIN fact_incidence i
    ON c.country_code = i.country_code AND c.year = i.year
GROUP BY c.country_code, c.year
ORDER BY c.country_code, c.year;


-- ---------------------------------------------------------------------------
-- EASY Q2: Drop-off rate between 1st dose and subsequent doses (DTP1 -> DTP3)
-- ---------------------------------------------------------------------------
SELECT
    country_code,
    year,
    MAX(CASE WHEN vaccine_code = 'DTP1' THEN coverage_pct END) AS dtp1_coverage,
    MAX(CASE WHEN vaccine_code = 'DTP3' THEN coverage_pct END) AS dtp3_coverage,
    ROUND(
        MAX(CASE WHEN vaccine_code = 'DTP1' THEN coverage_pct END)
        - MAX(CASE WHEN vaccine_code = 'DTP3' THEN coverage_pct END), 1
    ) AS dropoff_percentage_points
FROM fact_coverage
WHERE vaccine_code IN ('DTP1', 'DTP3')
GROUP BY country_code, year
ORDER BY dropoff_percentage_points DESC;


-- ---------------------------------------------------------------------------
-- EASY Q6: Has booster dose uptake (MCV2) increased over time?
-- ---------------------------------------------------------------------------
SELECT
    year,
    ROUND(AVG(coverage_pct), 1) AS avg_mcv2_booster_coverage
FROM fact_coverage
WHERE vaccine_code = 'MCV2'
GROUP BY year
ORDER BY year;


-- ---------------------------------------------------------------------------
-- EASY Q10: Which regions/countries have high disease incidence despite
-- high vaccination rates? (possible vaccine-effectiveness gaps)
-- ---------------------------------------------------------------------------
SELECT
    c.country_code,
    dc.country_name,
    dc.who_region,
    ROUND(AVG(c.coverage_pct), 1)  AS avg_coverage_pct,
    ROUND(AVG(i.incidence_rate), 2) AS avg_incidence_rate
FROM fact_coverage c
JOIN fact_incidence i ON c.country_code = i.country_code AND c.year = i.year
JOIN dim_country dc ON dc.country_code = c.country_code
GROUP BY c.country_code
HAVING avg_coverage_pct > 80 AND avg_incidence_rate > (
    SELECT AVG(incidence_rate) FROM fact_incidence
)
ORDER BY avg_incidence_rate DESC;


-- ---------------------------------------------------------------------------
-- MEDIUM Q1 & Q2: Trend in disease cases before/after vaccine introduction
-- ---------------------------------------------------------------------------
SELECT
    rc.country_code,
    rc.disease_code,
    rc.year,
    rc.cases,
    CASE
        WHEN rc.year >= (
            SELECT MIN(vi.year) FROM fact_vaccine_introduction vi
            WHERE vi.country_code = rc.country_code AND vi.introduced = 1
        ) THEN 'After Introduction'
        ELSE 'Before Introduction'
    END AS introduction_period
FROM fact_reported_cases rc
ORDER BY rc.country_code, rc.disease_code, rc.year;


-- ---------------------------------------------------------------------------
-- MEDIUM Q3: Which diseases show the most significant reduction in cases?
-- (compares average cases in first vs last 3 years of data per disease)
-- ---------------------------------------------------------------------------
WITH bounds AS (
    SELECT MIN(year) AS min_yr, MAX(year) AS max_yr FROM fact_reported_cases
),
early AS (
    SELECT disease_code, AVG(cases) AS avg_cases_early
    FROM fact_reported_cases, bounds
    WHERE year <= bounds.min_yr + 2
    GROUP BY disease_code
),
late AS (
    SELECT disease_code, AVG(cases) AS avg_cases_late
    FROM fact_reported_cases, bounds
    WHERE year >= bounds.max_yr - 2
    GROUP BY disease_code
)
SELECT
    e.disease_code,
    ROUND(e.avg_cases_early, 1) AS avg_cases_early_period,
    ROUND(l.avg_cases_late, 1)  AS avg_cases_late_period,
    ROUND(100.0 * (e.avg_cases_early - l.avg_cases_late) / NULLIF(e.avg_cases_early, 0), 1) AS pct_reduction
FROM early e
JOIN late l ON e.disease_code = l.disease_code
ORDER BY pct_reduction DESC;


-- ---------------------------------------------------------------------------
-- MEDIUM Q4: What % of the target population has been covered by each vaccine?
-- ---------------------------------------------------------------------------
SELECT
    vaccine_code,
    ROUND(SUM(doses) * 100.0 / NULLIF(SUM(target_number), 0), 1) AS pct_target_population_covered
FROM fact_coverage
GROUP BY vaccine_code
ORDER BY pct_target_population_covered DESC;


-- ---------------------------------------------------------------------------
-- MEDIUM Q6: Disparities in vaccine introduction timelines across WHO regions
-- ---------------------------------------------------------------------------
SELECT
    who_region,
    vaccine_description,
    MIN(CASE WHEN introduced = 1 THEN year END) AS earliest_introduction_year,
    MAX(CASE WHEN introduced = 1 THEN year END) AS latest_introduction_year
FROM fact_vaccine_introduction
GROUP BY who_region, vaccine_description
ORDER BY vaccine_description, earliest_introduction_year;


-- ---------------------------------------------------------------------------
-- SCENARIO Q1: Regions with low vaccination coverage (for resource allocation)
-- ---------------------------------------------------------------------------
SELECT
    dc.country_name,
    dc.who_region,
    ROUND(AVG(fc.coverage_pct), 1) AS avg_coverage_pct
FROM fact_coverage fc
JOIN dim_country dc ON dc.country_code = fc.country_code
WHERE fc.year = (SELECT MAX(year) FROM fact_coverage)
GROUP BY dc.country_name, dc.who_region
ORDER BY avg_coverage_pct ASC
LIMIT 10;


-- ---------------------------------------------------------------------------
-- SCENARIO Q6: Global progress toward 95% measles (MCV1) coverage target
-- ---------------------------------------------------------------------------
SELECT
    year,
    ROUND(AVG(coverage_pct), 1) AS avg_mcv1_coverage,
    ROUND(AVG(coverage_pct), 1) - 95 AS gap_to_95pct_target
FROM fact_coverage
WHERE vaccine_code = 'MCV1'
GROUP BY year
ORDER BY year;
