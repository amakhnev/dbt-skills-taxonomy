# PRD-02: Data Model

**Version:** 1.2
**Status:** Design
**Audience:** Data / Backend / Product
**Scope:** Canonical skills taxonomy, capability scoring model, inference via implied skills, SaaS tenant visibility

---

## 1. Purpose

Define an API-facing and dbt-managed data model that supports:

* Canonical **skills** with synonyms for reliable normalisation
* **Capabilities** as weighted groupings of skills for scoring
* Multi-source imports with traceability
* SaaS support via **global lifecycle** + **tenant-specific visibility**
* **Implied skills inference** (e.g., framework → language) to enrich normalised output

---

## 2. Non-goals

This design does not aim to model a full skills ontology/graph (e.g., broader/narrower/related) or general-purpose taxonomy navigation. Only the explicit inference requirement is represented as a directed “implies” edge.

---

## 3. Design principles

1. **Serveable marts:** Every marts table must have a direct use in matching, inference, scoring, or governance.
2. **Separate lifecycle from visibility:** Lifecycle describes the canonical catalogue; visibility describes what a tenant sees.
3. **Deterministic normalisation:** Synonyms and redirects produce stable canonical IDs.
4. **Inference is explicit:** Inferred skills are produced via `implies` edges and must be identifiable as inferred.
5. **Controlled expansion:** Inference must be bounded to avoid explosions and cycles.

---

## 4. Entity overview

### 4.1 ER overview (marts)

```
dim_skills ──< dim_skill_synonyms
    │
    ├──< dim_skill_redirects
    │
    ├──< bridge_skill_implies
    │
    └──< dim_skill_sources

dim_capabilities ──< bridge_capability_skills >── dim_skills
      │
      └──< dim_capability_sources

tenant_skill_visibility
tenant_capability_visibility
```

---

## 5. Core concepts

### 5.1 Canonical skill

A unique skill represented by `dim_skills.skill_id` (stable internal identifier).

### 5.2 Synonym

A text variant that should match the same canonical skill (e.g., “NodeJS”, “Node.js”, “node js”).

### 5.3 Redirect

A mapping from an obsolete/duplicate skill ID to the canonical skill ID (e.g., “nodejs_runtime” → “nodejs”).

### 5.4 Implied skill

A directed inference relationship where an observed skill implies another foundational skill (e.g., “Django” → “Python”). Implied skills are added to output as inferred, not as explicit mentions.

### 5.5 Capability

A scored concept (e.g., “Backend Engineering”) derived from weighted skills.

---

## 6. Lifecycle and visibility

### 6.1 Lifecycle state (global)

Used on canonical entities (skills, capabilities) and optionally on inference edges.

Allowed values:

* `draft` — exists in the catalogue, not in default serving set
* `published` — part of the serving set
* `deprecated` — still served/matchable, but not recommended for new use
* `suppressed` — not served by default; retained for history/dedupe

### 6.2 Tenant visibility (per tenant)

Tenant-specific overrides independent of lifecycle.

Allowed values:

* `enabled` — visible/servable for tenant
* `hidden` — excluded from tenant serving set

Default behaviour: if no tenant override exists, treat visibility as `enabled`.

---

## 7. Tables (marts)

### 7.1 `dim_skills`

| Column            | Type            | Description                                       |
| ----------------- | --------------- | ------------------------------------------------- |
| `skill_id`        | text (PK)       | Stable internal ID (slug from canonical name).    |
| `name`            | text            | Canonical display name.                           |
| `description`     | text (nullable) | Optional definition/description.                  |
| `skill_type`      | text            | `hard` or `soft`.                                 |
| `lifecycle_state` | text            | `draft`, `published`, `deprecated`, `suppressed`. |
| `created_at`      | timestamp       | Created timestamp.                                |
| `updated_at`      | timestamp       | Updated timestamp.                                |

Constraints / expectations:

* `skill_type` ∈ {`hard`,`soft`}
* `lifecycle_state` ∈ {`draft`,`published`,`deprecated`,`suppressed`}

---

### 7.2 `dim_skill_synonyms`

| Column         | Type      | Description                               |
| -------------- | --------- | ----------------------------------------- |
| `skill_id`     | text (FK) | References `dim_skills`.                  |
| `synonym`      | text      | Normalised synonym text (lowercase/trim). |
| `is_preferred` | boolean   | True for the canonical display synonym.   |
| `source`       | text      | `manual`, `lightcast`, `esco`, etc.       |

Primary key:

* (`skill_id`, `synonym`)

Notes:

* Synonyms are used for matching mentions to canonical skills.
* A canonical skill should have at least one preferred synonym.

---

### 7.3 `dim_skill_redirects`

| Column          | Type      | Description                                       |
| --------------- | --------- | ------------------------------------------------- |
| `from_skill_id` | text (PK) | Old/duplicate skill id.                           |
| `to_skill_id`   | text (FK) | Canonical skill id to redirect to.                |
| `reason`        | text      | `duplicate`, `renamed`, `merged`, `standardised`. |
| `created_at`    | timestamp | When the redirect was created.                    |

Rules:

* `from_skill_id != to_skill_id`

Notes:

* Redirects are applied after synonym resolution and before inference/scoring.

---

### 7.4 `bridge_skill_implies`

Directed inference edges used to expand extracted skills.

| Column            | Type         | Description                              |
| ----------------- | ------------ | ---------------------------------------- |
| `from_skill_id`   | text (FK)    | Observed skill (e.g., `django`).         |
| `to_skill_id`     | text (FK)    | Implied skill (e.g., `python`).          |
| `strength`        | numeric(3,2) | Confidence 0.00–1.00.                    |
| `source`          | text         | `manual`, `esco`, `lightcast`, etc.      |
| `lifecycle_state` | text         | `published`, `deprecated`, `suppressed`. |
| `created_at`      | timestamp    | Created timestamp.                       |
| `updated_at`      | timestamp    | Updated timestamp.                       |

Primary key:

* (`from_skill_id`, `to_skill_id`)

Rules:

* `from_skill_id != to_skill_id`
* `strength` between 0 and 1

Operational semantics:

* This relation is **one-way**: A implies B.
* Used for post-normalisation enrichment (explicit → inferred).
* Inference is bounded (see Section 9).

---

### 7.5 `dim_capabilities`

| Column            | Type            | Description                                       |
| ----------------- | --------------- | ------------------------------------------------- |
| `capability_id`   | text (PK)       | Stable internal ID.                               |
| `name`            | text            | Display name.                                     |
| `description`     | text (nullable) | Optional definition.                              |
| `group_name`      | text (nullable) | Optional grouping label for navigation/reporting. |
| `lifecycle_state` | text            | `draft`, `published`, `deprecated`, `suppressed`. |
| `created_at`      | timestamp       | Created timestamp.                                |
| `updated_at`      | timestamp       | Updated timestamp.                                |

Notes:

* `group_name` supports external categories without introducing scoring rollups.

---

### 7.6 `bridge_capability_skills`

| Column          | Type         | Description                          |
| --------------- | ------------ | ------------------------------------ |
| `capability_id` | text (FK)    | References `dim_capabilities`.       |
| `skill_id`      | text (FK)    | References `dim_skills` (canonical). |
| `weight`        | numeric(3,2) | Relevance weight 0.00–1.00.          |
| `source`        | text         | Mapping source.                      |

Primary key:

* (`capability_id`, `skill_id`)

Rules:

* `weight` between 0 and 1

---

### 7.7 `dim_skill_sources`

| Column        | Type            | Description                         |
| ------------- | --------------- | ----------------------------------- |
| `skill_id`    | text (FK)       | Canonical skill id.                 |
| `source`      | text            | `manual`, `lightcast`, `esco`, etc. |
| `source_id`   | text            | External ID in that source.         |
| `source_uri`  | text (nullable) | External URI if available.          |
| `imported_at` | timestamp       | When imported/mapped.               |

Primary key:

* (`skill_id`, `source`)

---

### 7.8 `dim_capability_sources`

| Column          | Type      | Description              |
| --------------- | --------- | ------------------------ |
| `capability_id` | text (FK) | Canonical capability id. |
| `source`        | text      | Source name.             |
| `source_id`     | text      | External ID.             |
| `imported_at`   | timestamp | When imported/mapped.    |

Primary key:

* (`capability_id`, `source`)

---

## 8. SaaS tenant overrides

### 8.1 `tenant_skill_visibility`

| Column             | Type            | Description              |
| ------------------ | --------------- | ------------------------ |
| `tenant_id`        | text/uuid       | Tenant identifier.       |
| `skill_id`         | text (FK)       | Canonical skill id.      |
| `visibility_state` | text            | `enabled` or `hidden`.   |
| `updated_at`       | timestamp       | When updated.            |
| `updated_by`       | text (nullable) | Optional actor id/email. |

Primary key:

* (`tenant_id`, `skill_id`)

Default:

* Missing row ⇒ `enabled`

---

### 8.2 `tenant_capability_visibility`

| Column             | Type            | Description              |
| ------------------ | --------------- | ------------------------ |
| `tenant_id`        | text/uuid       | Tenant identifier.       |
| `capability_id`    | text (FK)       | Canonical capability id. |
| `visibility_state` | text            | `enabled` or `hidden`.   |
| `updated_at`       | timestamp       | When updated.            |
| `updated_by`       | text (nullable) | Optional actor id/email. |

Primary key:

* (`tenant_id`, `capability_id`)

Default:

* Missing row ⇒ `enabled`

---

## 9. Serving and inference rules

### 9.1 Serving set (global)

Entities are eligible for serving when:

* `lifecycle_state IN ('published','deprecated')`

### 9.2 Tenant filter

After applying global lifecycle:

* exclude if tenant visibility is `hidden`
* include if tenant visibility missing or `enabled`

### 9.3 Normalisation pipeline (skills)

Given extracted mentions from a resume:

1. **Match** mention → `skill_id` using `dim_skill_synonyms`
2. **Resolve** redirects using `dim_skill_redirects` (canonicalise IDs)
3. **Expand** implied skills using `bridge_skill_implies`
4. **Deduplicate** final skill set
5. **Label** outputs:

   * explicit skills: derived from direct mention match
   * inferred skills: derived from implies edges

### 9.4 Inference bounds

To control growth and avoid loops:

* Default expansion is **1 hop**: only edges where `from_skill_id` is in the explicit set.
* Optionally support **2 hops** later behind a strict cap (e.g., max inferred skills per explicit skill).
* Block self-loops and optionally block immediate cycles (A→B and B→A).

### 9.5 Tenant-aware inference

Implied skill inclusion respects tenant skill visibility:

* if implied target is `hidden` for tenant, it is not included in tenant results.

---

## 10. Scoring rules (capabilities)

### 10.1 Skill contribution types

Each skill used in scoring has:

* `origin`: `explicit` or `inferred`
* `inference_strength` (only for inferred)

### 10.2 Recommended scoring behaviour

Capability score is computed from the intersection of extracted skills and `bridge_capability_skills`.

To avoid over-counting inferred skills:

* apply an inference discount factor

Example effective contribution:

* `effective_weight = weight * contribution_multiplier`
* where:

  * explicit: `contribution_multiplier = 1.0`
  * inferred: `contribution_multiplier = strength * inferred_multiplier`
  * `inferred_multiplier` is a tunable constant (e.g., 0.4–0.6)

Exact scoring formula is owned by the application/service; the data model provides the weights and inference metadata.

---

## 11. Reference query patterns

### 11.1 Tenant-aware synonym match + redirect canonicalisation

```sql
select
  coalesce(r.to_skill_id, s.skill_id) as canonical_skill_id,
  s.name,
  s.skill_type
from marts.dim_skill_synonyms syn
join marts.dim_skills s on s.skill_id = syn.skill_id
left join marts.dim_skill_redirects r on r.from_skill_id = s.skill_id
left join marts.tenant_skill_visibility tsv
  on tsv.skill_id = coalesce(r.to_skill_id, s.skill_id)
 and tsv.tenant_id = :tenant_id
where syn.synonym = lower(:mention)
  and s.lifecycle_state in ('published', 'deprecated')
  and coalesce(tsv.visibility_state, 'enabled') = 'enabled';
```

### 11.2 One-hop implied skills for explicit canonical skills

```sql
select
  i.from_skill_id as evidence_skill_id,
  i.to_skill_id as implied_skill_id,
  i.strength
from marts.bridge_skill_implies i
join marts.dim_skills tgt on tgt.skill_id = i.to_skill_id
left join marts.tenant_skill_visibility tsv
  on tsv.skill_id = i.to_skill_id
 and tsv.tenant_id = :tenant_id
where i.from_skill_id = any(:explicit_skill_ids)
  and i.lifecycle_state in ('published', 'deprecated')
  and tgt.lifecycle_state in ('published', 'deprecated')
  and coalesce(tsv.visibility_state, 'enabled') = 'enabled';
```

### 11.3 Tenant-aware capability weights for a set of skills

```sql
select
  c.capability_id,
  c.name,
  b.skill_id,
  b.weight
from marts.bridge_capability_skills b
join marts.dim_capabilities c on c.capability_id = b.capability_id
left join marts.tenant_capability_visibility tcv
  on tcv.capability_id = c.capability_id
 and tcv.tenant_id = :tenant_id
where b.skill_id = any(:skill_ids)
  and c.lifecycle_state in ('published', 'deprecated')
  and coalesce(tcv.visibility_state, 'enabled') = 'enabled';
```

---

## 12. Data quality rules (tests)

Recommended tests:

**`dim_skills`**

* `skill_id` unique, not null
* `skill_type` accepted values (`hard`,`soft`)
* `lifecycle_state` accepted values (`draft`,`published`,`deprecated`,`suppressed`)

**`dim_skill_synonyms`**

* unique (`skill_id`,`synonym`)
* not null columns
* at least one `is_preferred=true` per skill in serving set (singular test)

**`dim_skill_redirects`**

* `from_skill_id != to_skill_id`
* `to_skill_id` exists in `dim_skills`

**`bridge_skill_implies`**

* unique (`from_skill_id`,`to_skill_id`)
* `from_skill_id != to_skill_id`
* `strength` between 0 and 1
* referenced skills exist

**`bridge_capability_skills`**

* unique (`capability_id`,`skill_id`)
* `weight` between 0 and 1

**Tenant overrides**

* unique keys
* referenced IDs exist

---

## 13. Deliverables

* Marts schema as defined in Sections 7–8
* Serving + inference semantics as defined in Sections 9–10
* Standard tests as defined in Section 12
