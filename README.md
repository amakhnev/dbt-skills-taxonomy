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

* `data/lightcast/versions/lightcast_<version>.json`
* `data/lightcast/import_meta.json`

Example:

* `data/lightcast/versions/lightcast_v9.40.json`
* `data/lightcast/import_meta.json`:

  ```json
  {
    "version": "v9.40",
    "source": "lightcast",
    "notes": "Downloaded on 2026-02-23"
  }
  ```

### 2) Load into raw tables

```bash
uv run python scripts/load_lightcast.py \
  --file data/lightcast/versions/lightcast_v9.40.json \
  --meta data/lightcast/import_meta.json
```

This creates a new import batch, stores versioned raw rows, and marks the batch as **current**.

### 3) Transform + test

```bash
uv run dbt run --profiles-dir .
uv run dbt test --profiles-dir .
```

### 4) Updating to a newer Lightcast version

1. Add the new file under `data/lightcast/versions/`
2. Update `data/lightcast/import_meta.json` with the new `"version"`
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

## Adding a New Import Source

1. Define where the source files will live under `data/<source>/` (gitignored).
2. Add a loader script in `scripts/` to load raw data into `raw.<source>_*` tables.
3. Define dbt sources in `models/staging/<source>/`.
4. Create staging models that normalize the source into project conventions.
5. Update intermediate merge models to union/deduplicate with existing sources.
6. Extend marts and tests to validate the new source contributions.

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
