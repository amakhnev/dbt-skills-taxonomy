# dbt-skills-taxonomy

`dbt-skills-taxonomy` is a dbt project for building a normalized, queryable skills and capabilities taxonomy in PostgreSQL. The repository is structured to ingest multiple sources (manual/example seeds first, then Lightcast, ESCO, and future sources), transform them into a consistent model, and publish mart tables that can be consumed by an API.

## Prerequisites

- Python 3.12+
- `uv`
- Docker + Docker Compose

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
6. Run dbt (PRD-01 scaffolding has no models yet, so this is mostly a sanity check):
   ```bash
   uv run dbt run --profiles-dir .
   uv run dbt test --profiles-dir .
   ```

## Project Structure

- `.github/workflows/` - CI for linting and dbt compile checks
- `models/staging/` - Source-specific staging models (one subfolder per source)
- `models/intermediate/` - Cross-source merge and deduplication logic
- `models/marts/` - Final API-facing tables (`dim_*`, `bridge_*`)
- `seeds/` - Small curated datasets and example fixtures
- `macros/` - Reusable dbt macros (for example, slug generation)
- `tests/` - Singular data tests
- `snapshots/` - Snapshot models (if introduced later)
- `scripts/` - Python scripts to download/load external sources
- `data/` - Downloaded source files (gitignored cache)

## Adding a New Import Source

Follow the source pattern used in the PRDs:

1. Add Python download/load scripts in `scripts/` to fetch and load raw data.
2. Define dbt sources in `models/staging/<source>/`.
3. Create staging models that normalize the source into project conventions.
4. Update intermediate merge models to union/deduplicate with existing sources.
5. Extend marts and tests to validate the new source contributions.

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
