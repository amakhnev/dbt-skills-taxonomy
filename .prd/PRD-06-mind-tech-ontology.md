# PRD-06: MIND Tech Ontology Import

**Version:** 1.0
**Date:** February 2026
**Depends on:** PRD-01 (scaffolding), PRD-02 (data model), PRD-04/05 (multi-source import pattern)

---

## 1. Purpose

Import the **MIND Tech Skills & Concepts Ontology** (MIT-licensed) as a high-value source for:

* **Skill synonyms** (better normalisation / fewer missed matches) ([GitHub][1])
* **Implied skills** (e.g., framework → language) to enrich extracted skills via inference ([GitHub][1])
* **Concepts** that can be mapped into capabilities (optional serving, useful for filtering/analysis)

The repository provides `__aggregated_skills.json` and `__aggregated_concepts.json` in the repo root, plus per-skill/per-concept JSON files. ([GitHub][1])

---

## 2. Source overview

### 2.1 Repository

* GitHub: `MIND-TechAI/MIND-tech-ontology` ([GitHub][1])
* License: **MIT** ([GitHub][1])

### 2.2 Coverage (as published in repo README)

* ~**3333 skills**, **974 concepts**, **10897 relations** ([GitHub][1])
* Technical domains include Backend, Frontend, DevOps, MLOps, Data Engineering, Data Science, Cybersecurity, QA/Testing, Networking, etc. ([GitHub][1])

### 2.3 Skill JSON shape (important fields)

The README shows skill nodes containing (at least): `name`, `synonyms`, `type`, `technicalDomains`, and `impliesKnowingSkills` (plus multiple concept-related lists). ([GitHub][1])

---

## 3. Data mapping to PRD-02 tables

### 3.1 Skills → `dim_skills`

From each MIND skill entry:

* `skill_id` = `slugify(name)`
* `name` = `name`
* `description` = `null` (MIND aggregated file does not provide consistent descriptions in the README sample; keep future enrichment separate)
* `skill_type` = `hard` (MIND is tech skills-focused)
* `lifecycle_state` = `published` (so normalisation works immediately)

### 3.2 Synonyms → `dim_skill_synonyms`

From each skill’s `synonyms[]`:

* `synonym` = lower(trim(value))
* `is_preferred` = true for the synonym equal to lower(trim(name))
* `source` = `mind`

### 3.3 Implied skills → `bridge_skill_implies`

From each skill’s implied lists:

* Primary source: `impliesKnowingSkills[]` ([GitHub][1])
* Secondary source (high-value): `supportedProgrammingLanguages[]` (when present)

Mapping:

* `from_skill_id` = slugify(skill.name)
* `to_skill_id` = slugify(implied_skill_name)
* `strength`:

  * `impliesKnowingSkills` → 0.90
  * `supportedProgrammingLanguages` → 0.95
* `source` = `mind`
* `lifecycle_state` = `published`

Dedup rule:

* If multiple edges produce the same (`from_skill_id`,`to_skill_id`), keep one with `max(strength)`.

### 3.4 Concepts → `dim_capabilities` (draft by default)

From `__aggregated_concepts.json`:

* `capability_id` = slugify(concept.name)
* `name` = concept.name
* `group_name` = join(concept.category[], ' | ')  (category is a list)
* `lifecycle_state` = `draft` (prevents flooding the served capability set)

### 3.5 Technical domains → `dim_capabilities` (published)

From unique values in skills’ `technicalDomains[]` ([GitHub][1])

* `capability_id` = slugify(domain_name)
* `name` = domain_name
* `group_name` = `MIND Technical Domains`
* `lifecycle_state` = `published`

### 3.6 Skill → capability weights → `bridge_capability_skills`

Two mappings are produced:

**A) Domain membership (published capabilities)**

* From skills’ `technicalDomains[]`
* `weight` = 0.50
* `source` = `mind`

**B) Concept membership (draft capabilities)**
Map a skill to a concept capability if the skill references that concept in one of these lists (where the concept name exists in the concepts dataset):

* `solvesApplicationTasks[]`
* `associatedToApplicationDomains[]`
* `architecturalPatterns[]`
* `implementsPatternsByDefault[]`
* `conceptualAspects[]`
* `impliesKnowingConcepts[]`

Weights (per relation type), collapsed to one row per (capability_id, skill_id) using `max(weight)`:

* `solvesApplicationTasks` → 1.00
* `associatedToApplicationDomains` → 0.80
* `architecturalPatterns` → 0.70
* `implementsPatternsByDefault` → 0.70
* `conceptualAspects` → 0.60
* `impliesKnowingConcepts` → 0.40

### 3.7 Source traceability

Populate:

* `dim_skill_sources` with `source='mind'`, `source_id = original skill name`, `source_uri = repo URL`, `imported_at`
* `dim_capability_sources` similarly for MIND domains + concepts

---

## 4. Import pipeline

This follows the existing pattern: **download → load to raw → stage → merge into marts** (same shape as Lightcast/ESCO PRDs).  

### 4.1 `scripts/download_mind_ontology.py`

Responsibilities:

1. Download a specific repo ref (commit SHA, tag, or branch)
2. Save the aggregated JSON files:

   * `data/mind/__aggregated_skills.json`
   * `data/mind/__aggregated_concepts.json`
3. Save metadata:

   * `data/mind/import_meta.json` containing `{ref, downloaded_at, counts}`

Arguments:

* `--ref` (default: `main`)
* `--output-dir` (default: `data/mind/`)

### 4.2 `scryPostgreSQL raw schema tables (full replace each run).

Raw tables:

* `raw.mind_skills`
  Columns: `name text`, `payload jsonb`, `import_ref text`, `imported_at timestamp`
* `raw.mind_concepts`
  Columns: `name text`, `payload jsonb`, `import_ref text`, `imported_at timestamp`

Notes:

* Store the entire JSON node in `payload` to keep the import lossless.
* Use `jsonb` so dbt staging can safely explode arrays with Postgres JSON functions.

---

## 5. dbt models

### 5.1 Staging layer (`models/staging/mind/`)

```
models/staging/mind/
├── _mind__sources.yml
├── _mind__models.yml
├── stg_mind__skills.sql
├── stg_mind__skill_synonyms.sql
├── stg_mind__skill_implies.sql
├── stg_mind__capabilities.sql
├── stg_mind__capability_skills.sql
├── stg_mind__skill_sources.sql
└── stg_mind__capability_sources.sql
```

**`stg_mind__skills.sql`**

* Reads `raw.mind_skills`
* `skill_id = slugify(name)`
* `name`, `skill_type='hard'`, `lifecycle_state='published'`

**`stg_mind__skill_synonyms.sql`**

* Explodes `payload->'synonyms'` into rows
* Normalises to lower/trim
* Sets `is_preferred` based on match with canonical name

**`stg_mind__skill_implies.sql`**

* Explodes:

  * `payload->'impliesKnowingSkills'`
  * `payload->'supportedProgrammingLanguages'`
* Produces edges with strengths and dedup via `max(strength)` per pair

**`stg_mind__capabilities.sql`**

* Produces two sets:

  1. Domain capabilities from `technicalDomains[]` (published)
  2. Concept capabilities from `raw.mind_concepts` (draft)

**`stg_mind__capability_skills.sql`**

* Domain mapping: explode `technicalDomains[]`
* Concept mapping: explode concept reference arrays, join to known concepts by name, compute weights and collapse via `max(weight)` per pair

### 5.2 Intermediate layer (`models/intermediate/`)

Update the existing merge models to include `mind` as a source, keeping the established behaviour:

* **Deduplicate canonical skills** by `skill_id` using a source priority ordering
* **Synonyms are additive** (dedupe only exact `(skill_id, synonym)` pairs)
* **Implied edges are additive** (dedupe exact pairs, keep max strength)
* **Skill/capability sources are additive**

Recommended source priority for canonical rows (name/description/type):

1. `manual`
2. `lightcast`
3. `mind`
4. `esco`

Intermediate models impacted/required:

* `int_skills_merged`
* `int_synonyms_merged`
* `int_skill_implies_merged`
* `int_capabilities_merged`
* `int_capability_skills_merged`
* `int_skill_sources_merged`
* `int_capability_sources_merged`

### 5.3 Marts

Marts select from intermediate merged models and conform to PRD-02 table definitions.

---

## 6. Tests

### 6.1 Generic tests (staging)

* `stg_mind__skills.skill_id` not_null
* `stg_mind__skills.lifecycle_state` accepted (`published`)
* `stg_mind__skill_synonyms` unique combination of (`skill_id`,`synonym`)
* `stg_mind__skill_implies.strength` between 0 and 1
* `stg_mind__capability_skills.weight` between 0 and 1

### 6.2 Singular tests (project-level)

1. **All implied edges resolve**

* After merging, every `bridge_skill_implies.to_skill_id` and `from_skill_id` exists in `dim_skills`.

2. **No self-loops**

* No rows where `from_skill_id = to_skill_id` in implied edges.

3. **Preferred synonym exists**

* For served skills (`published`,`deprecated`), at least one preferred synonym exists.

4. **MIND concepts join quality (optional)**

* Report (not fail) the count of concept references in skills that do not exist in the concepts dataset, to catch drift in upstream data.

---

## 7. Running the import

```bash
# 1) Download the ontology (pin ref for reproducibility)
uv run python scripts/download_mind_ontology.py --ref main

# 2) Load into raw schema
uv run python scripts/load_mind_ontology.py

# 3) Transform
uv run dbt run

# 4) Validate
uv run dbt test
```

---

## 8. Deliverables

* [ ] `scripts/download_mind_ontology.py`
* [ ] `scripts/load_mind_ontology.py`
* [ ] Raw tables: `raw.mind_skills`, `raw.mind_concepts`
* [ ] Staging models under `models/staging/mind/`
* [ ] Intermediate merge updates to include `mind`
* [ ] New implied-skills merge model (`int_skill_implies_merged`) if not already present
* [ ] Tests (generic + singular) passing
* [ ] README updated with “MIND import” runbook and source notes (MIT license, pinned ref)

---

## 9. Notes on expected value

This import is specifically intended to improve:

* matching coverage via synonyms (e.g., small variations and misspellings) ([GitHub][1])
* recall via implied skill expansion (e.g., Next.js → React → JavaScript) ([GitHub][1])

[1]: https://github.com/MIND-TechAI/MIND-tech-ontology "GitHub - MIND-TechAI/MIND-tech-ontology: A comprehensive Tech Skills Ontology"
