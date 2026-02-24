# PRD-03: Example Seed Import

**Version:** 1.1
**Date:** February 2026
**Depends on:** PRD-01, PRD-02
**Scope:** Seed-driven implementation + validation of the marts model using a small fictional dataset 

---

## 1. Purpose

Implement the dbt models defined by PRD-02 and validate them end-to-end by loading a small fictional dataset via dbt seeds. The dataset is designed to exercise:

* canonical skills and synonyms (normalisation)
* redirects (duplicate/merged skills)
* implied skills inference (directed “A implies B”)
* capabilities and skill weights (scoring inputs)
* lifecycle state filtering (global serving set)
* tenant visibility overrides (SaaS filtering)
* source traceability tables

---

## 2. Example Dataset: Mind Management Institute

A deliberately fictional domain to avoid confusion with real taxonomies while still covering every behaviour.

### 2.1 Capabilities (flat)

All capabilities belong to the same conceptual group via `group_name = 'Mind Management'`.

| capability_id      | name             | group_name      |
| ------------------ | ---------------- | --------------- |
| `telepathy`        | Telepathy        | Mind Management |
| `remote-telepathy` | Remote Telepathy | Mind Management |
| `hypnosis`         | Hypnosis         | Mind Management |
| `mass-hypnosis`    | Mass Hypnosis    | Mind Management |

All are served with `lifecycle_state = 'published'`.

---

### 2.2 Skills

**Soft skills (examples):**

| skill_id              | name                | description                                               |
| --------------------- | ------------------- | --------------------------------------------------------- |
| `mind-reading`        | Mind Reading        | Perceive thoughts of others through focused concentration |
| `emotional-sensing`   | Emotional Sensing   | Detect emotional states without verbal cues               |
| `thought-guessing`    | Thought Guessing    | Predict likely thoughts based on behavioural patterns     |
| `suggestion-planting` | Suggestion Planting | Influence decisions through conversational technique      |
| `crowd-reading`       | Crowd Reading       | Sense collective mood and intent in large groups          |
| `future-prediction`   | Future Prediction   | Anticipate outcomes via psychic pattern recognition       |

**Hard skills (examples):**

| skill_id                        | name                          | description                                        |
| ------------------------------- | ----------------------------- | -------------------------------------------------- |
| `neurolink`                     | NeuroLink                     | Core NeuroLink platform fundamentals               |
| `neurolink-installation`        | NeuroLink Installation        | Install and configure NeuroLink interface devices  |
| `neurolink-operation`           | NeuroLink Operation           | Operate and monitor NeuroLink systems              |
| `thoughtbridge-operation`       | ThoughtBridge Operation       | Operate ThoughtBridge devices for thought transfer |
| `psychic-amplifier-calibration` | Psychic Amplifier Calibration | Calibrate amplifiers for long-range telepathy      |
| `mind-shield-configuration`     | Mind Shield Configuration     | Configure defensive barriers against intrusion     |
| `hypno-beam-operation`          | Hypno-Beam Operation          | Operate hypnotic induction devices                 |

All above are served with `lifecycle_state = 'published'`.

---

### 2.3 Synonyms (normalisation)

Each skill has at least its canonical name as a synonym (`is_preferred = true`). Selected examples:

| skill_id                  | synonyms                                                                                       |
| ------------------------- | ---------------------------------------------------------------------------------------------- |
| `mind-reading`            | `mind reading`, `mindreading`, `thought perception`, `telepathic reading`                      |
| `neurolink`               | `neurolink`, `neuro link`, `nl platform`                                                       |
| `neurolink-installation`  | `neurolink installation`, `neurolink setup`, `nl installation`, `brain interface installation` |
| `neurolink-operation`     | `neurolink operation`, `neurolink ops`, `nl ops`, `neurolink monitoring`                       |
| `thoughtbridge-operation` | `thoughtbridge operation`, `thought bridge`, `tb operation`, `thought transfer operation`      |
| `hypno-beam-operation`    | `hypno-beam operation`, `hypno beam`, `hypnobeam`, `hb operation`                              |

---

### 2.4 Redirects (duplicate/merged skills)

A small set of intentionally duplicated/obsolete skills exist as suppressed rows and redirect to canonical skills.

Example:

| from_skill_id              | to_skill_id           | reason    |
| -------------------------- | --------------------- | --------- |
| `telepathic-reading-skill` | `mind-reading`        | duplicate |
| `nl-ops-legacy`            | `neurolink-operation` | renamed   |

The `from_skill_id` skill rows exist in `dim_skills` with `lifecycle_state = 'suppressed'` so history/dedupe is testable.

---

### 2.5 Implied skills (inference edges)

Directed inference edges expand extracted skills into foundational skills (e.g., “operation/framework” implies “platform/language”).

Example:

| from_skill_id                   | to_skill_id | strength |
| ------------------------------- | ----------- | -------- |
| `neurolink-operation`           | `neurolink` | 0.90     |
| `neurolink-installation`        | `neurolink` | 0.85     |
| `thoughtbridge-operation`       | `neurolink` | 0.80     |
| `psychic-amplifier-calibration` | `telepathy` | 0.60     |

All implied edges are served with `lifecycle_state = 'published'`.

---

### 2.6 Capability–Skill mapping (weights)

**Telepathy:**

| skill_id                        | weight |
| ------------------------------- | -----: |
| `mind-reading`                  |   1.00 |
| `emotional-sensing`             |   0.70 |
| `thought-guessing`              |   0.60 |
| `neurolink-operation`           |   0.80 |
| `psychic-amplifier-calibration` |   0.50 |

**Remote Telepathy:**

| skill_id                        | weight |
| ------------------------------- | -----: |
| `mind-reading`                  |   0.90 |
| `psychic-amplifier-calibration` |   1.00 |
| `thoughtbridge-operation`       |   0.90 |
| `neurolink-operation`           |   0.70 |

**Hypnosis:**

| skill_id                    | weight |
| --------------------------- | -----: |
| `suggestion-planting`       |   1.00 |
| `crowd-reading`             |   0.50 |
| `hypno-beam-operation`      |   0.80 |
| `mind-shield-configuration` |   0.40 |

**Mass Hypnosis:**

| skill_id                        | weight |
| ------------------------------- | -----: |
| `crowd-reading`                 |   1.00 |
| `hypno-beam-operation`          |   0.90 |
| `suggestion-planting`           |   0.70 |
| `psychic-amplifier-calibration` |   0.60 |

---

### 2.7 Lifecycle state

This dataset exercises lifecycle filtering:

* Most rows are `lifecycle_state = 'published'`
* Redirect “from” skills are present and set to `lifecycle_state = 'suppressed'`
* Optionally include one deprecated skill (not required, but allowed)

---

### 2.8 Tenant visibility overrides

A single example tenant is used to test SaaS filtering:

* `tenant_id = 'tenant_mmi_lab'`
* Hide one capability and one skill:

Examples:

| tenant_id      | entity     | id                  | visibility_state |
| -------------- | ---------- | ------------------- | ---------------- |
| tenant_mmi_lab | capability | `mass-hypnosis`     | hidden           |
| tenant_mmi_lab | skill      | `future-prediction` | hidden           |

---

## 3. Seed Files

All seeds live in `seeds/example/`. Seed CSVs match the mart schemas exactly (minus any computed timestamps if your project chooses to set them in models).

| File                                        | Feeds                          |
| ------------------------------------------- | ------------------------------ |
| `example__skills.csv`                       | `dim_skills`                   |
| `example__skill_synonyms.csv`               | `dim_skill_synonyms`           |
| `example__skill_redirects.csv`              | `dim_skill_redirects`          |
| `example__skill_implies.csv`                | `bridge_skill_implies`         |
| `example__capabilities.csv`                 | `dim_capabilities`             |
| `example__capability_skills.csv`            | `bridge_capability_skills`     |
| `example__skill_sources.csv`                | `dim_skill_sources`            |
| `example__capability_sources.csv`           | `dim_capability_sources`       |
| `example__tenant_skill_visibility.csv`      | `tenant_skill_visibility`      |
| `example__tenant_capability_visibility.csv` | `tenant_capability_visibility` |

**Convention:** `source = 'manual'` for all rows in example seeds.

---

## 4. dbt Models

### 4.1 Staging

Seed-based staging models are pass-through, but still exist to enforce conventions and types.

```
models/staging/example/
├── _example__sources.yml
├── _example__models.yml
├── stg_example__skills.sql
├── stg_example__skill_synonyms.sql
├── stg_example__skill_redirects.sql
├── stg_example__skill_implies.sql
├── stg_example__capabilities.sql
├── stg_example__capability_skills.sql
├── stg_example__skill_sources.sql
├── stg_example__capability_sources.sql
├── stg_example__tenant_skill_visibility.sql
└── stg_example__tenant_capability_visibility.sql
```

Each staging model:

* `select * from {{ ref('example__...') }}` (or source() if configured as source)
* casts column types as needed
* ensures required columns exist

### 4.2 Intermediate

No intermediate layer is required for a single seed source. Intermediate models are introduced when multiple sources need merging/deduplication.

### 4.3 Marts

Marts match PRD-02 tables. For this PRD, marts select directly from corresponding staging models.

```
models/marts/
├── _marts__models.yml
├── dim_skills.sql
├── dim_skill_synonyms.sql
├── dim_skill_redirects.sql
├── bridge_skill_implies.sql
├── dim_capabilities.sql
├── bridge_capability_skills.sql
├── dim_skill_sources.sql
├── dim_capability_sources.sql
├── tenant_skill_visibility.sql
└── tenant_capability_visibility.sql
```

Example (`dim_skills.sql`):

```sql
with source as (
  select * from {{ ref('stg_example__skills') }}
)
select
  skill_id,
  name,
  description,
  skill_type,
  lifecycle_state,
  created_at,
  updated_at
from source
```

---

## 5. Tests

### 5.1 Generic tests (YAML)

**`dim_skills`**

* `skill_id`: unique, not_null
* `name`: not_null
* `skill_type`: accepted_values (`hard`, `soft`)
* `lifecycle_state`: accepted_values (`draft`, `published`, `deprecated`, `suppressed`)

**`dim_skill_synonyms`**

* `skill_id`: relationships to `dim_skills`
* `synonym`: not_null
* compound unique: (`skill_id`, `synonym`) via `dbt_utils.unique_combination_of_columns`

**`dim_skill_redirects`**

* `from_skill_id`: relationships to `dim_skills`
* `to_skill_id`: relationships to `dim_skills`
* `reason`: not_null

**`bridge_skill_implies`**

* `from_skill_id`: relationships to `dim_skills`
* `to_skill_id`: relationships to `dim_skills`
* `strength`: not_null
* `lifecycle_state`: accepted_values (`published`, `deprecated`, `suppressed`)
* compound unique: (`from_skill_id`, `to_skill_id`)

**`dim_capabilities`**

* `capability_id`: unique, not_null
* `name`: not_null
* `lifecycle_state`: accepted_values (`draft`, `published`, `deprecated`, `suppressed`)

**`bridge_capability_skills`**

* `skill_id`: relationships to `dim_skills`
* `capability_id`: relationships to `dim_capabilities`
* `weight`: not_null
* compound unique: (`capability_id`, `skill_id`)

**`dim_skill_sources`**

* compound unique: (`skill_id`, `source`)
* `skill_id`: relationships to `dim_skills`

**`dim_capability_sources`**

* compound unique: (`capability_id`, `source`)
* `capability_id`: relationships to `dim_capabilities`

**Tenant overrides**

* `tenant_skill_visibility`: unique (`tenant_id`,`skill_id`), relationships to `dim_skills`, accepted `visibility_state` (`enabled`,`hidden`)
* `tenant_capability_visibility`: unique (`tenant_id`,`capability_id`), relationships to `dim_capabilities`, accepted `visibility_state` (`enabled`,`hidden`)

---

### 5.2 Singular tests (SQL in `tests/`)

**`test_every_served_skill_has_preferred_synonym.sql`**
Every skill in the serving set (`published`,`deprecated`) must have at least one synonym with `is_preferred = true`.

**`test_weights_in_range.sql`**
All `bridge_capability_skills.weight` values are between 0.00 and 1.00.

**`test_implies_strength_in_range.sql`**
All `bridge_skill_implies.strength` values are between 0.00 and 1.00.

**`test_no_self_redirect_or_implies.sql`**

* No redirect where `from_skill_id = to_skill_id`
* No implies where `from_skill_id = to_skill_id`

---

## 6. Validation Queries

Place these in `analyses/` (or README) and verify results are sensible after `dbt seed`, `dbt run`, `dbt test`.

### 6.1 Find a skill by synonym (serving set)

```sql
select s.skill_id, s.name, s.skill_type
from dim_skills s
join dim_skill_synonyms syn on s.skill_id = syn.skill_id
where syn.synonym = 'nl ops'
  and s.lifecycle_state in ('published', 'deprecated');
```

### 6.2 Resolve a redirect to canonical

```sql
select
  r.from_skill_id,
  r.to_skill_id as canonical_skill_id
from dim_skill_redirects r
where r.from_skill_id = 'nl-ops-legacy';
```

### 6.3 One-hop implied skills expansion (explicit → inferred)

```sql
-- Assume explicit skill is neurolink-operation
select
  i.from_skill_id as evidence_skill_id,
  i.to_skill_id as implied_skill_id,
  i.strength
from bridge_skill_implies i
where i.from_skill_id = 'neurolink-operation'
  and i.lifecycle_state in ('published', 'deprecated');
```

### 6.4 Tenant visibility filtering (skills)

```sql
select s.skill_id, s.name
from dim_skills s
left join tenant_skill_visibility tsv
  on tsv.skill_id = s.skill_id
 and tsv.tenant_id = 'tenant_mmi_lab'
where s.lifecycle_state in ('published', 'deprecated')
  and coalesce(tsv.visibility_state, 'enabled') = 'enabled'
order by s.skill_id;
```

### 6.5 Capabilities for a skill (weights)

```sql
select c.name as capability, b.weight
from dim_capabilities c
join bridge_capability_skills b on c.capability_id = b.capability_id
where b.skill_id = 'mind-reading'
  and c.lifecycle_state in ('published', 'deprecated')
order by b.weight desc;
```

---

## 7. Documentation

* All models and columns must have `description` in YAML schema files.
* `dbt docs generate` must produce complete documentation.
* DAG should show: seeds → staging → marts.

---

## 8. Deliverables

* Seed CSVs in `seeds/example/` as defined in Section 3
* Staging models in `models/staging/example/` as defined in Section 4.1
* Mart models in `models/marts/` as defined in Section 4.3
* Generic tests in YAML + singular tests in `tests/`
* Validation queries in `analyses/`
* Successful runs:

  * `dbt seed`
  * `dbt run`
  * `dbt test` (0 failures)
  * `dbt docs generate`
