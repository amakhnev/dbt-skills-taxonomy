# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-24

### Added

- **Unified taxonomy pipeline**: Staging from three sources (example seeds, Lightcast Open Skills, MIND Tech Ontology), intermediate merge layer, and API-ready marts for skills, synonyms, redirects, implies, capabilities, and source attributions.
- **Lightcast versioning**: Versioned JSON imports with batch metadata; diff models to compare current vs previous batch.
- **Tenant visibility**: Marts for per-tenant skill and capability visibility (example-backed; ready for multi-tenant use).
- **Capability lifecycle analyses**: Queries for publish/depublish and dedup candidates to support capability curation.
- **Data loaders**: `load_lightcast.py` (versioned imports + meta), `load_mind_ontology.py` (MIND aggregated skills/concepts).

---

## [0.1.0] - 2026-02-22

### Added

- Initial repository scaffolding for dbt skills taxonomy project
- dbt project configuration, packages, and example profile
- Docker Compose PostgreSQL setup for local development
- SQLFluff and pre-commit configuration
- GitHub Actions CI workflow for lint and compile checks
- Project directory skeleton for models, seeds, macros, tests, snapshots, and scripts
