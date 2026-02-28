# dbt-skills-taxonomy

`dbt-skills-taxonomy` is a dbt project for building a **normalized, queryable skills + capabilities taxonomy** in PostgreSQL.

It ingests multiple sources, transforms them into a consistent model, and publishes **API-facing mart tables** (skills, synonyms, implied-skill relations, capabilities, and bridges for scoring / matching).

Current sources in scope:

* **Example/manual seeds** (fixtures for development and tests)
* **Lightcast Open Skills** (versioned imports; includes descriptions + category/subcategory)
* **MIND Tech Ontology** (skills, synonyms, implied skills, and concepts-as-capabilities)


## Prerequisites

* Python 3.12+
* `uv`
* Docker + Docker Compose


## Quick Start

1. Clone the repository.
2. Start PostgreSQL:
   ```bash
   docker compose up -d
   ```
3. Install Python tooling:
   ```bash
   uv sync
   ```
4. Create a local dbt profile from the example:
   ```bash
   cp profiles.yml.example profiles.yml
   ```
5. Install dbt packages:
   ```bash
   uv run dbt deps --profiles-dir .
   ```
6. Run seeds + build + tests:

   ```bash
   uv run dbt seed --profiles-dir .
   uv run dbt run --profiles-dir .
   uv run dbt test --profiles-dir .
   ```

---

## Loading Lightcast (versioned)

Lightcast files are provided manually and stored in a gitignored folder.

### 1) Place files

* `data/lightcast/lightcast_<version>.json`
* `data/lightcast/import_meta.json`

Example:

* `data/lightcast/lightcast_v9.40.json`
* `data/lightcast/import_meta.json`:

  ```json
  {
    "version": "v9.40",
    "filename": "lightcast_v9.40.json",
    "source": "lightcast",
    "notes": "Downloaded on 2026-02-23"
  }
  ```

### 2) Load into raw tables

```bash
uv run python scripts/load_lightcast.py \
  --meta data/lightcast/import_meta.json
```

This creates a new import batch, stores versioned raw rows, and marks the batch as **current**.

### 3) Transform + test

```bash
uv run dbt run --profiles-dir .
uv run dbt test --profiles-dir .
```

### 4) Updating to a newer Lightcast version

1. Add the new file under `data/lightcast/lightcast_<version>.json`
2. Update `data/lightcast/import_meta.json` with the new `"version"`, `"filename"`
3. Re-run the loader and dbt

The project includes diff models so you can inspect what changed between the new current batch and the previous one.

---

## Loading MIND Tech Ontology

MIND files are provided manually and stored in a gitignored folder.

### 1) Place files

Copy the aggregated files into:

* `data/mind/__aggregated_skills.json`
* `data/mind/__aggregated_concepts.json`

### 2) Load into raw tables

```bash
uv run python scripts/load_mind_ontology.py
```

### 3) Transform + test

```bash
uv run dbt run --profiles-dir .
uv run dbt test --profiles-dir .
```

## Project Structure

* `.github/workflows/` - CI for linting and dbt compile checks
* `models/staging/` - Source-specific staging models (one subfolder per source)
* `models/intermediate/` - Cross-source merge and deduplication logic
* `models/marts/` - Final API-facing tables (`dim_*`, `bridge_*`)
* `seeds/example/` - Fictional Mind Management Institute dataset (PRD-03)
* `macros/` - Reusable dbt macros
* `tests/` - Singular data tests (self-loops, range checks, preferred synonyms)
* `scripts/` - Python scripts to load external source files into `raw.*`
* `data/` - Source files (gitignored)
* `docs/marts_schema.json` - Single-file marts table reference for applications (columns, types, FKs, enums)

## Adding a New Import Source

1. Define where the source files will live under `data/<source>/` (gitignored).
2. Add a loader script in `scripts/` to load raw data into `raw.<source>_*` tables.
3. Define dbt sources in `models/staging/<source>/`.
4. Create staging models that normalize the source into project conventions.
5. Update intermediate merge models to union/deduplicate with existing sources.
6. Extend marts and tests to validate the new source contributions.

## Deploying to Production

### 1) Add the production profile

Copy `profiles.yml.example` and ensure the `prod` target is configured.
The example file already includes a `prod` output that reads from environment variables:

```yaml
prod:
  type: postgres
  host: "{{ env_var('PROD_DB_HOST') }}"
  port: "{{ env_var('PROD_DB_PORT', '5432') | int }}"
  user: "{{ env_var('PROD_DB_USER') }}"
  password: "{{ env_var('PROD_DB_PASSWORD') }}"
  dbname: "{{ env_var('PROD_DB_NAME', 'skills_taxonomy') }}"
  schema: skills
  threads: 4
```

Set the environment variables before running any commands:

#### Bash (Linux/macOS):

```bash
export PROD_DB_HOST=your-prod-host
export PROD_DB_PORT=5432
export PROD_DB_USER=your-prod-user
export PROD_DB_PASSWORD=your-prod-password
export PROD_DB_NAME=skills_taxonomy
```

#### PowerShell (Windows):

```powershell
$env:PROD_DB_HOST="your-prod-host"
$env:PROD_DB_PORT="5432"
$env:PROD_DB_USER="your-prod-user"
$env:PROD_DB_PASSWORD="your-prod-password"
$env:PROD_DB_NAME="skills_taxonomy"
```


### 2) Prepare data files

Before deploying, ensure all required source data is in place:

| Source | Files | Location |
|--------|-------|----------|
| Example seeds | Included in repo | `seeds/example/*.csv` |
| Lightcast | `lightcast_<version>.json` + `import_meta.json` | `data/lightcast/` |
| MIND Ontology | `__aggregated_skills.json` + `__aggregated_concepts.json` | `data/mind/` |

For the initial deployment only the example seeds are required. Lightcast and MIND
files should be loaded via their respective scripts before running dbt (see sections above).

**Raw schema:** The `raw` schema (and Lightcast/MIND raw tables) are created by dbt
run-operations. The deploy steps below include these so the first deploy creates them.
If you deploy without the run-operations, run once:

```bash
uv run dbt run-operation create_lightcast_raw_tables --profiles-dir . --target prod
uv run dbt run-operation create_mind_raw_tables --profiles-dir . --target prod
```

**Loading Lightcast/MIND into production:** The Python load scripts do not read the dbt
profile; they use `--db-url` or the `DATABASE_URL` environment variable. To load data
into production, set `DATABASE_URL` to your production Postgres URL, then run the
loaders (from the project root, with `data/lightcast/` or `data/mind/` in place):

```bash
# Build prod URL from same vars as dbt (bash)
export DATABASE_URL="postgresql://${PROD_DB_USER}:${PROD_DB_PASSWORD}@${PROD_DB_HOST}:${PROD_DB_PORT}/${PROD_DB_NAME}"
uv run python scripts/load_lightcast.py --meta data/lightcast/import_meta.json
uv run python scripts/load_mind_ontology.py
```

PowerShell (Windows):

```powershell
$env:DATABASE_URL = "postgresql://$($env:PROD_DB_USER):$($env:PROD_DB_PASSWORD)@$($env:PROD_DB_HOST):$($env:PROD_DB_PORT)/$($env:PROD_DB_NAME)"
uv run python scripts/load_lightcast.py --meta data/lightcast/import_meta.json
uv run python scripts/load_mind_ontology.py
```

Then run the deploy (or `uv run dbt run --profiles-dir . --target prod` and `dbt test`) to build models from the loaded raw data.

### 3) Incremental deploy (safe, no data loss)

This is the default mode. Staging and intermediate models are views (always recreated).
Marts tables are rebuilt via `create table as` but **do not drop upstream raw/seed data**.

```bash
# Create raw schema and raw tables if missing (first deploy or new DB)
uv run dbt run-operation create_lightcast_raw_tables --profiles-dir . --target prod
uv run dbt run-operation create_mind_raw_tables --profiles-dir . --target prod

# Install packages
uv run dbt deps --profiles-dir . --target prod

# Load seed data (inserts only, does not drop existing seed tables)
uv run dbt seed --profiles-dir . --target prod

# Build all models
uv run dbt run --profiles-dir . --target prod

# Validate
uv run dbt test --profiles-dir . --target prod
```

**Windows (PowerShell):** Set `PROD_DB_*` env vars, then run `.\scripts\deploy.ps1`. The
script runs the raw-table run-operations, deps, seed, run, and test. Use
`.\scripts\deploy.ps1 -FullRefresh` for a full refresh.

This is safe to run repeatedly. Seeds use `INSERT` by default and marts tables are
replaced atomically (`CREATE OR REPLACE` / `DROP + CREATE` within a transaction).

### 4) Full refresh (destructive rebuild)

Use this when seed schemas have changed, column types were updated, or you want to
guarantee a clean slate. This **drops and recreates** all seed tables and marts tables.

```bash
# Full-refresh seeds (drops + recreates seed tables)
uv run dbt seed --profiles-dir . --target prod --full-refresh

# Full-refresh models (drops + recreates all tables)
uv run dbt run --profiles-dir . --target prod --full-refresh

# Validate
uv run dbt test --profiles-dir . --target prod
```

**Warning:** `--full-refresh` on seeds will delete and reload all seed data. If you have
external loaders writing to raw tables (Lightcast, MIND), those are unaffected since they
live in separate schemas. Only seed-managed tables in the `seeds` schema are reset.

### 5) Dry run (preview without applying)

To see what dbt would do without touching the database:

```bash
uv run dbt compile --profiles-dir . --target prod
```

This generates compiled SQL in `target/compiled/` for review.

---

## Working with Data

The `analyses/` folder contains pre-built SQL queries for data quality and governance tasks.

**Marts schema reference for applications:** `docs/marts_schema.json` describes all marts tables (columns, types, nullability, enums, primary/unique keys, and foreign keys). Use it for API contracts, code generation, or documentation. Tables live in the dbt target schema (e.g. `skills`).
Compile them with:

```bash
uv run dbt compile --select "analyses/*" --profiles-dir .
```

Compiled SQL is written to `target/compiled/skills_taxonomy/analyses/` and can be run
directly against the database.

### Capability publish candidates

`analyses/capability_publish_candidates.sql` — finds draft capabilities that have skills
linked to them, ranked by skill count. Use this to identify which draft capabilities are
mature enough to promote to published.

### Capability depublish candidates

`analyses/capability_depublish_candidates.sql` — finds capabilities with zero skills linked.
These are empty shells that may need to be removed or demoted to draft.

### Capability deduplication candidates

`analyses/capability_dedup_candidates.sql` — finds pairs of capabilities whose skill sets
overlap significantly, scored by Jaccard similarity (intersection / union). Pairs scoring
0.3+ are flagged as merge candidates.

---

## Development Workflow

1. `uv sync`
2. `pre-commit install`
3. `docker compose up -d`
4. `cp profiles.yml.example profiles.yml`
5. `uv run dbt deps --profiles-dir .`
6. `uv run sqlfluff lint models/`
7. `uv run dbt compile --profiles-dir .`

## License

Apache License 2.0. See `LICENSE`.
