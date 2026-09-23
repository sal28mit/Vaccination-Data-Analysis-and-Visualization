# Vaccination Data Analysis and Visualization

A complete, runnable solution for the project brief: clean vaccination/disease
data → normalized SQL database → exploratory analysis → Power BI dashboards.

All pipeline steps are **Jupyter notebooks** (`.ipynb`) — run them in order,
top to bottom.

---

## ⚠️ About the data

The brief points to a dataset hosted on Google Drive rather than an attached
file. This solution ships with **realistic, structurally-identical sample
data** (built by notebook `01`) so the entire pipeline runs end-to-end out of
the box.

**To use the real dataset instead:**
1. Download the 5 CSVs from the Google Drive link in the brief.
2. Name them exactly as below and place them in `data/raw/`.
3. **Skip notebook `01`** and start at notebook `02`.

| Expected filename | Brief's table |
|---|---|
| `coverage_data.csv` | Table 1: coverage data |
| `incidence_rate.csv` | Table 2: Incidence Rate |
| `reported_cases.csv` | Table 3: Reported cases |
| `vaccine_introduction.csv` | Table 4: Vaccine Introduction |
| `vaccine_schedule_data.csv` | Table 5: Vaccine Schedule Data |

Column names are case/space-insensitive — notebook `02` standardizes them to
`snake_case` automatically. If your real file uses substantially different
column names, each notebook has an inline note showing exactly which
`rename()` mappings to adjust.

---

## Project structure
```
vaccination_project/
├── data/
│   ├── raw/                          # input CSVs (sample or real)
│   └── cleaned/                      # output of the cleaning notebook
├── scripts/
│   ├── 01_generate_sample_data.ipynb   # creates sample data (skip if using real data)
│   ├── 02_data_cleaning.ipynb          # missing data, units, dates, de-dup
│   ├── 03_create_database.ipynb        # builds + loads vaccination.db (SQLite)
│   └── 04_eda_analysis.ipynb           # EDA charts -> outputs/charts/ (renders inline too)
├── sql/
│   ├── schema.sql                    # normalized star-schema DDL
│   └── analysis_queries.sql          # answers to brief's analysis questions
├── powerbi/
│   └── POWER_BI_SETUP.md             # full dashboard-build walkthrough
├── outputs/charts/                   # PNG exhibits from the EDA notebook
├── vaccination.db                    # the built SQLite database
└── README.md                         # this file
```

---

## How to run — step by step

### 1. Install requirements
You need Python 3.9+, Jupyter, and a few libraries:
```bash
pip install jupyter pandas numpy matplotlib seaborn --break-system-packages
```
(Drop `--break-system-packages` if you're using a virtual environment, which
is recommended: `python3 -m venv venv && source venv/bin/activate` first.)

### 2. Launch Jupyter
From the `vaccination_project/` folder:
```bash
cd vaccination_project
jupyter notebook
```
This opens Jupyter in your browser. Navigate into the `scripts/` folder.

> The notebooks auto-detect the project root whether Jupyter's working
> directory is `scripts/` (the default when you open a notebook from there)
> or the project root itself — no path edits needed either way.

### 3. Run the notebooks in order
Open each notebook and run all cells top-to-bottom (**Cell → Run All**, or
step through with **Shift+Enter**):

| Order | Notebook | What it does | Skip if... |
|---|---|---|---|
| 1 | `01_generate_sample_data.ipynb` | Generates sample CSVs into `data/raw/` | you placed the real dataset there instead |
| 2 | `02_data_cleaning.ipynb` | Cleans all 5 tables → `data/cleaned/` | never — always run |
| 3 | `03_create_database.ipynb` | Builds `vaccination.db` and loads all tables | never — always run |
| 4 | `04_eda_analysis.ipynb` | Runs EDA, renders + saves 7 charts | optional, but recommended before Power BI |

Each notebook prints a "Next step" message at the end telling you which
notebook to open next, and each one asserts its required input exists
(with a clear error telling you which prior notebook to run) if you run
them out of order.

### 4. Explore the SQL layer directly (optional)
`sql/schema.sql` — the full normalized database design (3 dimension tables +
5 fact tables, with keys and indexes).
`sql/analysis_queries.sql` — 10 ready-to-run queries answering specific
questions from the brief (see list below); run them with any SQLite client,
e.g.:
```bash
sqlite3 vaccination.db < sql/analysis_queries.sql
```

### 5. Build the Power BI dashboard
Open **`powerbi/POWER_BI_SETUP.md`** — a complete walkthrough covering:
- 3 ways to connect Power BI to `vaccination.db` (ODBC live connection, CSV
  export, or migrating to a full RDBMS for scheduled refresh)
- Building the data model and relationships
- Core DAX measures (copy-paste ready)
- A 7-page report layout (Overview, Geographic, Trends, Scatter, Drop-off,
  Rollout Timeline, KPI Progress) mapped directly to the brief's "Key
  Visualizations" and Business Use Cases
- Slicers, drill-through, bookmarks, formatting, and publishing

---

## Data cleaning approach (notebook `02`)
- **Missing data:** numeric metrics (coverage %, incidence rate) are imputed
  with the group median (by antigen/category or by disease/denominator) —
  preserves distribution shape better than a global mean/zero-fill. Rows
  missing non-recoverable identifying fields are dropped, not guessed.
- **Normalize units:** coverage is clipped to a strict 0–100% range;
  denominator/category text fields are lower/upper-cased consistently.
- **Date consistency:** all `year` fields are coerced to integers and
  filtered to a sane 1990–2025 range.
- **De-duplication:** exact duplicate rows are dropped at load time.

## Database design (notebook `03` + `sql/schema.sql`)
Star-schema style: `dim_country`, `dim_disease`, `dim_vaccine` dimension
tables plus five fact tables (one per source table in the brief), joined on
`country_code` (+ `year` where relevant). See `sql/schema.sql` for full DDL
with primary/foreign keys and indexes for the common `country + year` filter
pattern.

## Answered analysis questions
`sql/analysis_queries.sql` (and the matching charts in notebook `04`)
answer:
- Coverage vs. incidence correlation (Easy Q1/Q9)
- DTP1 → DTP3 drop-off rate (Easy Q2)
- Booster (MCV2) uptake trend (Easy Q6)
- High incidence despite high coverage (Easy Q10)
- Disease case trends before/after vaccine introduction (Medium Q1/Q2)
- Diseases with the largest case reduction (Medium Q3)
- % of target population covered per vaccine (Medium Q4)
- Vaccine introduction timeline disparities by WHO region (Medium Q6)
- Lowest-coverage countries for resource allocation (Scenario Q1)
- Progress toward the 95% measles target (Scenario Q6)

## Notes / next steps for a real submission
1. Swap in the real dataset (see note at top) and re-run notebooks `02`–`04`
   — the cleaning logic is data-driven, not hard-coded to the sample data's
   distribution.
2. Build the actual `.pbix` following `powerbi/POWER_BI_SETUP.md`, using
   Option A or C there for a live/refreshable connection.
3. Expand `sql/analysis_queries.sql` to cover any remaining brief questions
   not yet scripted (mostly ones needing the vaccine-schedule table, e.g.
   schedule/booster-dose impact on coverage).
