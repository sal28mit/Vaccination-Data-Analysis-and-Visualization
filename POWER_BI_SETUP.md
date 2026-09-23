# Power BI Dashboard — Full Walkthrough

This guide takes you from the `vaccination.db` file produced by the notebooks
all the way to a finished, interactive multi-page Power BI report, matching
every item in the brief's "Power BI Integration" and "Data Visualization"
sections.

---

## Part 1 — Connect Power BI to the database

Power BI Desktop has no built-in SQLite connector, so pick **one** option.

### Option A — ODBC (recommended: live, refreshable connection)
1. Download & install the SQLite ODBC driver (64-bit, matching your Power BI
   install): http://www.ch-werner.de/sqliteodbc/
2. Open **ODBC Data Sources (64-bit)** on Windows (search the Start Menu) →
   **System DSN** tab → **Add** → select `SQLite3 ODBC Driver`.
3. In the driver setup dialog:
   - **Data Source Name:** `VaccinationDB`
   - **Database Name:** browse to your `vaccination.db` file path
   - Click **OK**.
4. Open **Power BI Desktop** → **Home → Get Data → More… → Other → ODBC** →
   **Connect**.
5. Choose the `VaccinationDB` DSN from the dropdown → **OK**.
6. In the Navigator window, check the boxes for all 8 tables:
   `dim_country`, `dim_disease`, `dim_vaccine`, `fact_coverage`,
   `fact_incidence`, `fact_reported_cases`, `fact_vaccine_introduction`,
   `fact_vaccine_schedule` → **Load**.

### Option B — CSV export (no driver install needed, but no live refresh)
Run this once per table (from the project root, needs the `sqlite3` CLI):
```bash
mkdir -p powerbi/exports
sqlite3 vaccination.db -header -csv "SELECT * FROM dim_country;" > powerbi/exports/dim_country.csv
sqlite3 vaccination.db -header -csv "SELECT * FROM dim_disease;" > powerbi/exports/dim_disease.csv
sqlite3 vaccination.db -header -csv "SELECT * FROM dim_vaccine;" > powerbi/exports/dim_vaccine.csv
sqlite3 vaccination.db -header -csv "SELECT * FROM fact_coverage;" > powerbi/exports/fact_coverage.csv
sqlite3 vaccination.db -header -csv "SELECT * FROM fact_incidence;" > powerbi/exports/fact_incidence.csv
sqlite3 vaccination.db -header -csv "SELECT * FROM fact_reported_cases;" > powerbi/exports/fact_reported_cases.csv
sqlite3 vaccination.db -header -csv "SELECT * FROM fact_vaccine_introduction;" > powerbi/exports/fact_vaccine_introduction.csv
sqlite3 vaccination.db -header -csv "SELECT * FROM fact_vaccine_schedule;" > powerbi/exports/fact_vaccine_schedule.csv
```
Then in Power BI: **Get Data → Text/CSV**, import each file, **Load**.

### Option C — Migrate to a client-server RDBMS (best for scheduled refresh in the Power BI Service)
1. Open `sql/schema.sql` and adjust the identity-column syntax:
   - SQL Server: `INTEGER PRIMARY KEY AUTOINCREMENT` → `INT IDENTITY(1,1) PRIMARY KEY`
   - Postgres: → `SERIAL PRIMARY KEY`
   - MySQL: → `INT AUTO_INCREMENT PRIMARY KEY`
2. Run the adjusted script on your server to create the schema.
3. Point `03_create_database.ipynb`'s `sqlite3.connect(DB_PATH)` cell at a
   SQLAlchemy engine for your server instead (`pyodbc`/`psycopg2`/
   `mysql-connector`) — the `pandas.to_sql()` calls work unchanged.
4. In Power BI: **Get Data → SQL Server** (or the matching connector) →
   point at your server/database → **Load**. This is the smoothest path to
   scheduled refresh once published to the Power BI Service.

---

## Part 2 — Build the data model

1. Switch to the **Model** view (left-hand icon strip).
2. Power BI usually auto-detects relationships from matching column names.
   Verify each of these exists (drag from one field to the other to create
   any that are missing); all should be **one-to-many** (dimension → fact,
   single direction unless noted):

   | From (dimension) | To (fact) | Join column |
   |---|---|---|
   | `dim_country[country_code]` | `fact_coverage[country_code]` | country_code |
   | `dim_country[country_code]` | `fact_incidence[country_code]` | country_code |
   | `dim_country[country_code]` | `fact_reported_cases[country_code]` | country_code |
   | `dim_country[country_code]` | `fact_vaccine_introduction[country_code]` | country_code |
   | `dim_country[country_code]` | `fact_vaccine_schedule[country_code]` | country_code |
   | `dim_disease[disease_code]` | `fact_incidence[disease_code]` | disease_code |
   | `dim_disease[disease_code]` | `fact_reported_cases[disease_code]` | disease_code |
   | `dim_vaccine[vaccine_code]` | `fact_coverage[vaccine_code]` | vaccine_code |
   | `dim_vaccine[vaccine_code]` | `fact_vaccine_schedule[vaccine_code]` | vaccine_code |

3. Create a shared **Year** table so every visual filters consistently even
   when comparing tables that don't directly relate to each other:
   - **Home → New Table** (Table tools ribbon), name it `dim_year`, formula:
     ```
     dim_year = DATATABLE("year", INTEGER, {{2010},{2011},{2012},{2013},{2014},{2015},{2016},{2017},{2018},{2019},{2020},{2021},{2022},{2023}})
     ```
     (Or simpler: relate on the existing `year` columns directly — a
     dedicated year table is a nice-to-have, not required, since every
     fact table already carries `year`.)
   - Relate `dim_year[year]` (one) to each fact table's `year` column (many).

---

## Part 3 — Core DAX measures

Create a new **Measures table** (Home → Enter Data → name it `_Measures`,
no columns needed) to keep calculations organized, then add these (Home →
New Measure):

```DAX
Avg Coverage % =
AVERAGE(fact_coverage[coverage_pct])

Avg Incidence Rate =
AVERAGE(fact_incidence[incidence_rate])

Total Reported Cases =
SUM(fact_reported_cases[cases])

Total Doses Administered =
SUM(fact_coverage[doses])

Pct Target Population Covered =
DIVIDE(SUM(fact_coverage[doses]), SUM(fact_coverage[target_number]))

Countries Below 80% Coverage =
CALCULATE(
    DISTINCTCOUNT(fact_coverage[country_code]),
    FILTER(fact_coverage, fact_coverage[coverage_pct] < 80)
)

DTP1 Coverage =
CALCULATE([Avg Coverage %], fact_coverage[vaccine_code] = "DTP1")

DTP3 Coverage =
CALCULATE([Avg Coverage %], fact_coverage[vaccine_code] = "DTP3")

DTP1 to DTP3 Dropoff (pp) =
[DTP1 Coverage] - [DTP3 Coverage]

MCV1 Coverage =
CALCULATE([Avg Coverage %], fact_coverage[vaccine_code] = "MCV1")

Gap to 95pct Measles Target =
[MCV1 Coverage] - 95

YoY Coverage Change =
VAR CurrentYear = [Avg Coverage %]
VAR PriorYear =
    CALCULATE([Avg Coverage %], DATEADD(dim_year[year], -1, YEAR))
RETURN CurrentYear - PriorYear
```

> If you skipped creating `dim_year`, replace the `DATEADD` in the last
> measure with a manual pattern instead:
> `CALCULATE([Avg Coverage %], fact_coverage[year] = MAX(fact_coverage[year]) - 1)`

---

## Part 4 — Build the report pages

Create one page per row below (**Home → New Page**), matching the brief's
"Key Visualizations" (geographical heatmaps, trend lines/bar charts, scatter
plots, KPI indicators) and its Business Use Cases.

### Page 1 — Overview (KPI Indicators)
1. Insert 4 **Card** visuals across the top:
   `Avg Coverage %`, `Avg Incidence Rate`, `Total Reported Cases`,
   `Countries Below 80% Coverage`.
2. Below them, add a **Line chart**: X-axis = `year`, Y-axis = `Avg Coverage
   %` and `Avg Incidence Rate` (dual-axis: put the second measure in the
   **Line 2 → Y-axis (secondary)** well) — this directly answers **Easy
   Q1/Q9**.
3. Add slicers along the left: `dim_country[who_region]`, `year` (slider),
   `dim_vaccine[vaccine_code]`.

### Page 2 — Geographic (Heatmaps)
1. Insert a **Filled Map** or **ArcGIS Map** visual: **Location** =
   `dim_country[country_name]`, **Color saturation** = `Avg Coverage %`.
   Add a second map (or toggle via a bookmark/button) with **Color
   saturation** = `Avg Incidence Rate`.
   > If country names don't geocode cleanly, add a field that matches
   > Bing's geocoding, or plot by `country_code` using an ISO-3 shape map
   > custom visual from AppSource for pixel-perfect regions.
2. Add a **Matrix** visual as a fallback/companion: rows = `who_region` →
   `country_name`, values = `Avg Coverage %`, `Avg Incidence Rate` —
   conditional-formatted as a heatmap (**Format → Conditional formatting →
   Background color** on the value fields) for **Scenario Q1**.

### Page 3 — Trends (Line & Bar Charts)
1. **Line chart:** X = `year`, Y = `Avg Coverage %`, **Legend** =
   `vaccine_code` — lets a user compare antigens over time.
2. **Clustered bar chart:** X = `who_region`, Y = `Total Reported Cases`,
   **Legend** = `disease_code` — shows regional disease burden.
3. **Line chart:** the `MCV2 Coverage` trend for **Easy Q6** (booster
   uptake over time) — reuse the query in `sql/analysis_queries.sql`
   (`-- EASY Q6`) as a DirectQuery/SQL source if you want it pre-aggregated
   instead of built with DAX.
4. Add a slicer for `year` as a range slider so the whole page is
   filterable to any period.

### Page 4 — Coverage vs. Effectiveness (Scatter Plot)
1. Insert a **Scatter chart**: X = `Avg Coverage %`, Y = `Avg Incidence
   Rate`, **Legend/Details** = `dim_country[country_name]`, **Size** =
   `Total Doses Administered` (optional, adds a bubble-chart dimension).
2. This directly visualizes **Medium Q7** and **Easy Q10** (countries in
   the top-right quadrant = high coverage but still high incidence — flag
   these for investigation into vaccine effectiveness or reporting
   accuracy).
3. Add a reference/trend line (**Format → Analytics pane → Trend line**).

### Page 5 — Dose Drop-off (Bar Chart)
1. **Clustered bar chart:** X = `country_name`, Y = `[DTP1 Coverage]` and
   `[DTP3 Coverage]` side-by-side — visual answer to **Easy Q2**.
2. Add a **Table** visual with columns `country_name`, `DTP1 Coverage`,
   `DTP3 Coverage`, `DTP1 to DTP3 Dropoff (pp)`, sorted descending by
   drop-off, to surface which countries lose the most people between doses.

### Page 6 — Vaccine Rollout Timeline
1. Insert a **Line and stacked column chart** or a **Gantt chart** (custom
   visual from AppSource): rows/categories = `vaccine_description`, values
   = earliest `year` where `fact_vaccine_introduction[introduced] = 1`,
   grouped by `who_region` — answers **Medium Q6** (disparities in vaccine
   introduction timelines across WHO regions).
2. Add a **Stacked bar chart**: X = `who_region`, Y = count of vaccines
   introduced, **Legend** = `introduced` (Yes/No) for the most recent year,
   to spot regions still lacking key vaccines.

### Page 7 — Progress vs. Target (KPI Indicator)
1. Insert a **KPI visual**: Indicator = `[MCV1 Coverage]`, Target =
   constant `95`, Trend axis = `year` — a built-in visual answer to
   **Scenario Q6** (WHO's 95% measles target by 2030).
2. Add a **Gauge visual**: Value = `[MCV1 Coverage]` for the latest year,
   Target = `95`, Minimum = `0`, Maximum = `100`.

---

## Part 5 — Filters & interactivity

- Add a **Slicer panel** (a dedicated thin page or a persistent filter pane
  via **Sync Slicers**) with: `who_region`, `country_name`, `year` (range),
  `vaccine_code`, `disease_code`. Use **View → Sync Slicers** to apply the
  same filters across every page.
- Enable **drill-through**: right-click a country in any chart → **Add
  drill-through** on a new "Country Detail" page showing that country's
  full coverage/incidence/case history — supports the brief's "Public
  Health Strategy" use case (assessing effectiveness by region).
- Use **Bookmarks** (View → Bookmarks) to create a toggle between the
  "Coverage" and "Incidence" map layers on Page 2, triggered by buttons.

---

## Part 6 — Formatting & publishing

1. **Format → Theme**: pick a clean built-in theme or import a custom JSON
   theme for consistent colors across pages.
2. Rename each page (double-click the tab) to match the section names
   above (Overview, Geographic, Trends, etc.).
3. **File → Publish → Publish to Power BI** (requires a Power BI account) to
   share the live report, or **File → Export → Export to PDF** for a static
   handout.
4. If using Option A (ODBC) or Option C (server) above, set up a **scheduled
   refresh** in the Power BI Service (**Dataset settings → Scheduled
   refresh**) so the dashboard stays current as new data lands in the
   database.

---

## Reference: pre-written SQL for each visual

Every chart above has a matching, tested SQL query in
`sql/analysis_queries.sql` (run against `vaccination.db`). If you'd rather
pull pre-aggregated results straight from SQL than build everything with
DAX, paste the relevant query into **Get Data → ODBC → Advanced options →
SQL statement** (or the equivalent "native query" box for your connector).
