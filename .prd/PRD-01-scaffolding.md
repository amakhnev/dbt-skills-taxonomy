# PRD-01: Repository Scaffolding

**Version:** 1.0
**Date:** February 2026

---

## 1. Purpose

Set up the `dbt-skills-taxonomy` repository with all tooling, CI, and development workflow. No data models, no imports — just a working dbt project that compiles cleanly.

---

## 2. Repository

- **Location:** `github.com/amakhnev/dbt-skills-taxonomy`
- **License:** Apache 2.0

---

## 3. Tooling

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.12+ | Runtime |
| uv | Latest | Package management |
| dbt-core | Latest stable | Transformation engine |
| dbt-postgres | Latest stable | PostgreSQL adapter |
| SQLFluff | Latest stable | SQL linting (dbt templater) |
| pre-commit | Latest | Git hooks |

---

## 4. Project Structure

```
dbt-skills-taxonomy/
├── .github/workflows/
│   └── ci.yml                    # sqlfluff lint + dbt compile on PRs
├── models/
│   ├── staging/                  # One subfolder per import source
│   ├── intermediate/             # Cross-source logic
│   └── marts/                    # Final tables for the API
├── seeds/                        # Small reference data, example datasets
├── macros/
├── tests/                        # Singular data tests
├── snapshots/
├── scripts/                      # Python: download/load external sources
├── data/                         # Downloaded source files (gitignored)
├── dbt_project.yml
├── packages.yml                  # dbt_utils
├── profiles.yml.example
├── docker-compose.yml            # Local PostgreSQL for dev
├── pyproject.toml
├── .sqlfluff
├── .pre-commit-config.yaml
├── .env.example
├── .gitignore
├── CHANGELOG.md
├── LICENSE
└── README.md
```

---

## 5. Configuration

### 5.1 `dbt_project.yml`

```yaml
name: skills_taxonomy
version: '0.1.0'
config-version: 2
profile: skills_taxonomy

model-paths: ["models"]
seed-paths: ["seeds"]
test-paths: ["tests"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

clean-targets: ["target", "dbt_packages"]

models:
  skills_taxonomy:
    staging:
      +materialized: view
      +schema: staging
    intermediate:
      +materialized: view
      +schema: intermediate
    marts:
      +materialized: table
      +schema: marts

seeds:
  skills_taxonomy:
    +schema: seeds
```

### 5.2 `profiles.yml.example`

```yaml
skills_taxonomy:
  target: dev
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('DB_HOST', 'localhost') }}"
      port: "{{ env_var('DB_PORT', '5432') | int }}"
      user: "{{ env_var('DB_USER', 'postgres') }}"
      password: "{{ env_var('DB_PASSWORD', 'postgres') }}"
      dbname: "{{ env_var('DB_NAME', 'skills_taxonomy') }}"
      schema: public
      threads: 4
```

### 5.3 `docker-compose.yml`

```yaml
services:
  postgres:
    image: postgres:16
    ports: ["5432:5432"]
    environment:
      POSTGRES_DB: skills_taxonomy
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - pgdata:/var/lib/postgresql/data
volumes:
  pgdata:
```

### 5.4 `packages.yml`

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
```

---

## 6. CI Pipeline (`.github/workflows/ci.yml`)

On pull requests to `main`:

1. `uv sync`
2. `dbt deps`
3. `sqlfluff lint models/`
4. `dbt compile`

No database needed — `dbt compile` validates syntax and refs.

---

## 7. SQLFluff Config (`.sqlfluff`)

```ini
[sqlfluff]
dialect = postgres
templater = dbt
max_line_length = 120

[sqlfluff:indentation]
indent_unit = space
tab_space_size = 4

[sqlfluff:rules:capitalisation.keywords]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.identifiers]
capitalisation_policy = lower

[sqlfluff:rules:capitalisation.functions]
capitalisation_policy = lower
```

---

## 8. Naming Conventions

| Layer | Pattern | Example |
|-------|---------|---------|
| Seeds | `{dataset}__{entity}` | `example__skills` |
| Staging | `stg_{source}__{entity}` | `stg_lightcast__skills` |
| Intermediate | `int_{entity}_{verb}` | `int_skills_merged` |
| Marts | `dim_{entity}` or `fct_{entity}` | `dim_skills`, `dim_capabilities` |

Columns: `snake_case`. PKs: `{entity}_id`. Booleans: `is_` / `has_`. Timestamps: `_at`.

---

## 9. README

Cover: what the project does (one paragraph), prerequisites, quick start (clone → docker compose up → dbt run → dbt test), project structure overview, how to add a new import source, development workflow, license.

---

## 10. Deliverables

- [ ] Repository created with all config files listed above
- [ ] `dbt compile` passes
- [ ] `sqlfluff lint` passes
- [ ] CI workflow runs on PR
- [ ] README complete
- [ ] CHANGELOG with v0.1.0 entry
