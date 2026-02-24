# PRD-04: Lightcast Import

**Version:** 1.4
**Date:** February 2026
**Depends on:** PRD-01, PRD-02 (current)

---

## 1. Purpose

Import a **user-provided Lightcast Open Skills JSON export** into PostgreSQL and transform it with dbt into canonical marts tables:

* `dim_skills` (with **description** populated for API use)
* `dim_skill_synonyms`
* `dim_skill_sources`
* `dim_capabilities` (from **subcategory**)
* `bridge_capability_skills` (skill → subcategory capability)

This PRD also defines **version update** handling because Lightcast publishes updates frequently, including new skills and changes to existing records.

The file shape is a single JSON document containing a top-level `data[]` array and optional `attributions[]`. 

---

## 2. Input contract (manual provisioning)

### 2.1 User-provided files

The user downloads Lightcast data in compliance with all applicable terms and places it into:

* `data/lightcast/lightcast_<version>.json`

Example: `data/lightcast/lightcast_v9.40.json` 

The user must also provide:

* `data/lightcast/import_meta.json` (required)

Minimum `import_meta.json`:

```json
{
  "version": "v9.40",
  "filename": "lightcast_v9.40.json",
  "source": "lightcast",
  "notes": "Downloaded on 2026-02-23"
}
```

### 2.2 JSON fields expected per `data[]` element

This PRD assumes the export is enriched and includes:

* `id` (string, stable Lightcast skill id)
* `name` (string)
* `type.id`, `type.name` (object)
* `infoUrl` (string)
* `description` (string, nullable)
* `descriptionSource` (string, nullable)
* `category.id`, `category.name` (object, nullable)
* `subcategory.id`, `subcategory.name` (object, nullable)
* `tags[]` (array of key/value objects, optional)
* `isSoftware` (boolean, optional)
* `isLanguage` (boolean, optional)

A similar structure exists in the attached file for core fields (`id`, `name`, `type`, `infoUrl`) and top-level `data`/`attributions`. 

### 2.3 Source API reference (informational)

The enriched field selection corresponds to:
`/skills/versions/<version>/skills?fields=tags,name,isSoftware,id,subcategory,descriptionSource,isLanguage,category,type,description,infoUrl`
(This is a reference for the expected fields; this PRD does not implement downloading.)

---

## 3. Canonical mapping (PRD-02 alignment)

### 3.1 Stable identity requirement across Lightcast versions

Lightcast may rename a skill while keeping the same `id`. If `skill_id` were derived from `slugify(name)` on every load, a rename would create a new canonical ID and pollute the taxonomy.

**Requirement:** Canonical `skill_id` for Lightcast must remain stable across versions even if `name` changes.

This PRD achieves that via a persistent mapping table `raw.lightcast_skill_id_map` (Section 4).

### 3.2 `dim_skills`

For each Lightcast skill record:

* `skill_id` = stable internal id from `raw.lightcast_skill_id_map` (not recomputed from name each run)
* `name` = Lightcast `name`
* `description` = Lightcast `description` (nullable)
* `skill_type` mapping:

  * if `type.name = 'Common Skill'` → `soft`
  * otherwise → `hard` (includes `Specialized Skill`, `Certification`, and unknowns)
* `lifecycle_state` = `var('lightcast_default_lifecycle_state', 'published')`
* `created_at` / `updated_at` = derived from batch timestamps (Section 6)

### 3.3 `dim_skill_synonyms`

One preferred synonym per Lightcast skill (additional synonyms may come from other sources later):

* `skill_id`
* `synonym` = `lower(trim(name))`
* `is_preferred` = `true`
* `source` = `lightcast`

### 3.4 `dim_skill_sources`

* `skill_id`
* `source` = `lightcast`
* `source_id` = Lightcast `id`
* `source_uri` = `infoUrl`
* `imported_at` = batch load timestamp

### 3.5 `dim_capabilities` from Lightcast subcategory

Lightcast `subcategory` is mapped to a capability:

* `capability_id` = `lc_subcat_<subcategory.id>` (stable)
* `name` = `subcategory.name`
* `group_name` = `category.name` (when present)
* `description` = null
* `lifecycle_state` = `published` (default)
* timestamps = batch timestamps

### 3.6 `bridge_capability_skills` (skill → subcategory)

If a skill has subcategory, create:

* `capability_id` = `lc_subcat_<subcategory.id>`
* `skill_id` = stable `skill_id`
* `weight` = `1.00`
* `source` = `lightcast`

If subcategory is missing, no capability mapping is created.

### 3.7 `dim_capability_sources`

* `capability_id`
* `source` = `lightcast`
* `source_id` = `subcategory.id` (as string)
* `imported_at` = batch timestamp

---

## 4. Raw schema (versioned loads + stable ID mapping)

Lightcast updates must be stored as **multiple batches** with a single “current” batch selected for dbt transformations.

### 4.1 Tables (PostgreSQL DDL)

```sql
create schema if not exists raw;

-- Tracks import batches (one per file load)
create table if not exists raw.lightcast_import_batches (
    import_batch_id      text primary key,
    version_label        text not null,
    file_path            text not null,
    file_sha256          text not null,
    imported_at          timestamptz not null default now(),
    skill_count          integer not null,
    attribution_count    integer not null,
    is_current           boolean not null default false,
    previous_batch_id    text null
);

create unique index if not exists uq_lightcast_current_batch
    on raw.lightcast_import_batches(is_current)
    where is_current = true;

-- Persistent mapping for stable internal IDs across Lightcast renames
create table if not exists raw.lightcast_skill_id_map (
    source_id        text primary key,  -- Lightcast skill id
    skill_id         text not null,     -- stable internal id used in marts
    first_seen_at    timestamptz not null default now(),
    last_seen_at     timestamptz not null default now(),
    first_name       text not null,
    last_name        text not null
);

create unique index if not exists uq_lightcast_skill_id_map_skill_id
    on raw.lightcast_skill_id_map(skill_id);

-- Versioned skill rows
create table if not exists raw.lightcast_skills (
    import_batch_id     text not null references raw.lightcast_import_batches(import_batch_id),
    source_id           text not null,              -- Lightcast id
    skill_id            text not null,              -- stable internal id from mapping table
    name                text not null,
    type_id             text,
    type_name           text,
    info_url            text,
    description         text,
    description_source  text,
    category_id         integer,
    category_name       text,
    subcategory_id      integer,
    subcategory_name    text,
    is_software         boolean,
    is_language         boolean,
    payload             jsonb not null,
    imported_at         timestamptz not null default now(),
    primary key (import_batch_id, source_id)
);

create index if not exists idx_lightcast_skills_batch
    on raw.lightcast_skills(import_batch_id);

create index if not exists idx_lightcast_skills_skill_id
    on raw.lightcast_skills(skill_id);

create index if not exists idx_lightcast_skills_subcategory
    on raw.lightcast_skills(subcategory_id);

-- Versioned attributions (optional)
create table if not exists raw.lightcast_attributions (
    import_batch_id  text not null references raw.lightcast_import_batches(import_batch_id),
    name             text not null,
    text             text not null,
    imported_at      timestamptz not null default now()
);

create index if not exists idx_lightcast_attr_batch
    on raw.lightcast_attributions(import_batch_id);
```

---

## 5. Loader implementation (Python, version-aware, stable IDs)

### 5.1 Script: `scripts/load_lightcast.py`

#### Responsibilities

1. Read `data/lightcast/import_meta.json` (required)
2. Read the JSON file mentioned in the `import_meta.json` file
3. Compute `file_sha256`
4. Create a new `import_batch_id` (recommended: `lightcast_<version_label>_<yyyymmddhhmmss>`)
5. Insert a row into `raw.lightcast_import_batches` (with counts filled after load)
6. For each skill record:

   * resolve stable `skill_id` using `raw.lightcast_skill_id_map`
   * insert row into `raw.lightcast_skills` with extracted columns + full `payload`
7. Insert any `attributions[]` into `raw.lightcast_attributions`
8. Update `raw.lightcast_import_batches.skill_count`, `attribution_count`
9. Mark this batch as `is_current=true` and flip previous current to false (transactionally)
10. Store `previous_batch_id` for diffing

#### CLI

```bash
uv run python scripts/load_lightcast.py \
  --meta data/lightcast/import_meta.json \
  --set-current \
  --db-url postgresql://...
```

Defaults:

* `--meta` default: `data/lightcast/import_meta.json`
* `--set-current` default: true

#### Streaming parsing

Use `ijson` (recommended) to iterate:

* `attributions.item`
* `data.item`

The attached file includes top-level `data` and `attributions`. 

### 5.2 Stable ID resolution algorithm

For each skill record with Lightcast `id = source_id` and `name`:

1. Query `raw.lightcast_skill_id_map` by `source_id`.
2. If exists:

   * reuse `skill_id`
   * set `last_seen_at = now()`
   * set `last_name = current name`
3. If missing:

   * generate a new internal `skill_id`:

     * `skill_id = slugify(name)` (Python slugify that matches dbt macro intent)
     * if collision occurs (another row already has that `skill_id`), append suffix: `-2`, `-3`, etc.
   * insert into `raw.lightcast_skill_id_map` with `first_name=last_name=name`

This ensures:

* skill identity is stable across versions
* name updates do not create new canonical IDs
* collisions are handled deterministically

### 5.3 Extracted columns per skill row

From each `data[]` item:

* `source_id` = `id`
* `skill_id` = from map (above)
* `name` = `name`
* `type_id` = `type.id`
* `type_name` = `type.name`
* `info_url` = `infoUrl`
* `description` = `description` (nullable)
* `description_source` = `descriptionSource` (nullable)
* `category_id` = `category.id` (nullable)
* `category_name` = `category.name` (nullable)
* `subcategory_id` = `subcategory.id` (nullable)
* `subcategory_name` = `subcategory.name` (nullable)
* `is_software` = `isSoftware` (nullable)
* `is_language` = `isLanguage` (nullable)
* `payload` = full JSON object
* `import_batch_id`, `imported_at`

### 5.4 Version update observability (loader output)

After loading a new current batch, the script prints a summary comparing **current** vs **previous** current batch:

Required counters:

* `added_skills_count` (new `source_id`)
* `removed_skills_count` (source_id disappeared)
* `renamed_skills_count` (same `source_id`, name changed)
* `type_changed_count` (same `source_id`, type_name changed)
* `description_changed_count` (same `source_id`, description changed)
* `category_changed_count` (same `source_id`, category_id changed)
* `subcategory_changed_count` (same `source_id`, subcategory_id changed)

---

## 6. dbt implementation

### 6.1 Sources (`models/staging/lightcast/_lightcast__sources.yml`)

```yaml
version: 2

sources:
  - name: raw
    schema: raw
    tables:
      - name: lightcast_import_batches
      - name: lightcast_skill_id_map
      - name: lightcast_skills
      - name: lightcast_attributions
```

### 6.2 Macros

**Current batch id macro** (`macros/lightcast_current_batch_id.sql`):

```sql
{% macro lightcast_current_batch_id() %}
(
  select import_batch_id
  from {{ source('raw', 'lightcast_import_batches') }}
  where is_current = true
  limit 1
)
{% endmacro %}
```

**Slugify macro** remains as shared utility (if needed in other sources). Lightcast itself uses the loader-resolved `skill_id`, not dbt slugify.

### 6.3 Staging models (current batch only)

Folder: `models/staging/lightcast/`

#### `stg_lightcast__skills.sql`

```sql
with src as (
  select *
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
)

select
  skill_id,
  name,
  description,
  case
    when type_name = 'Common Skill' then 'soft'
    else 'hard'
  end as skill_type,
  '{{ var("lightcast_default_lifecycle_state", "published") }}' as lifecycle_state,
  imported_at as created_at,
  imported_at as updated_at,
  'lightcast' as source,

  -- diagnostics (not selected into marts unless you choose to)
  source_id as lightcast_source_id,
  category_id,
  category_name,
  subcategory_id,
  subcategory_name,
  description_source,
  is_software,
  is_language
from src;
```

#### `stg_lightcast__skill_synonyms.sql`

```sql
with src as (
  select skill_id, name
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
)

select
  skill_id,
  lower(trim(name)) as synonym,
  true as is_preferred,
  'lightcast' as source
from src;
```

#### `stg_lightcast__skill_sources.sql`

```sql
with src as (
  select skill_id, source_id, info_url, imported_at
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
)

select
  skill_id,
  'lightcast' as source,
  source_id,
  info_url as source_uri,
  imported_at
from src;
```

#### `stg_lightcast__capabilities.sql` (subcategory → capability)

```sql
with src as (
  select distinct
    subcategory_id,
    subcategory_name,
    category_name,
    imported_at
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
    and subcategory_id is not null
)

select
  'lc_subcat_' || cast(subcategory_id as text) as capability_id,
  subcategory_name as name,
  cast(null as text) as description,
  category_name as group_name,
  'published' as lifecycle_state,
  min(imported_at) as created_at,
  max(imported_at) as updated_at,
  'lightcast' as source,
  cast(subcategory_id as text) as lightcast_subcategory_source_id
from src
group by 1,2,3,4,5,8,9;
```

#### `stg_lightcast__capability_skills.sql`

```sql
with src as (
  select
    skill_id,
    subcategory_id
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
    and subcategory_id is not null
)

select
  'lc_subcat_' || cast(subcategory_id as text) as capability_id,
  skill_id,
  cast(1.00 as numeric(3,2)) as weight,
  'lightcast' as source
from src;
```

#### `stg_lightcast__capability_sources.sql`

```sql
with src as (
  select distinct
    subcategory_id,
    imported_at
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
    and subcategory_id is not null
)

select
  'lc_subcat_' || cast(subcategory_id as text) as capability_id,
  'lightcast' as source,
  cast(subcategory_id as text) as source_id,
  min(imported_at) as imported_at
from src
group by 1,2,3;
```

### 6.4 Intermediate merge models

The intermediate layer merges multiple sources into marts. Lightcast contributes:

* skills (with descriptions)
* preferred synonyms
* sources
* capabilities (subcategories)
* capability-skill weights

Rules:

* Canonical skills dedupe by `skill_id` using source priority.
* Synonyms/sources/capabilities/bridge rows are additive (dedupe exact keys).

Recommended canonical skill priority (field winner):

1. `manual`
2. `lightcast`
3. `mind`
4. `esco`

For capabilities, because Lightcast subcategories have stable prefixed IDs (`lc_subcat_...`), they typically do not collide with other sources and can be safely additive.

Minimum intermediate models to include Lightcast:

* `int_skills_merged`
* `int_synonyms_merged`
* `int_skill_sources_merged`
* `int_capabilities_merged`
* `int_capability_skills_merged`
* `int_capability_sources_merged`

---

## 7. Version update diff models (dbt)

These models provide structured visibility into what changed between the current and previous batch.

Folder: `models/intermediate/lightcast/`

### 7.1 `int_lightcast__batch_pair.sql`

```sql
with batches as (
  select *
  from {{ source('raw', 'lightcast_import_batches') }}
),
current as (
  select import_batch_id, previous_batch_id
  from batches
  where is_current = true
)
select * from current;
```

### 7.2 `int_lightcast__skill_diff.sql`

```sql
with pair as (
  select * from {{ ref('int_lightcast__batch_pair') }}
),
curr as (
  select source_id, name, type_name, description, category_id, subcategory_id
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = (select import_batch_id from pair)
),
prev as (
  select source_id, name, type_name, description, category_id, subcategory_id
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = (select previous_batch_id from pair)
),
joined as (
  select
    coalesce(c.source_id, p.source_id) as source_id,
    p.name as prev_name,
    c.name as curr_name,
    p.type_name as prev_type_name,
    c.type_name as curr_type_name,
    p.description as prev_description,
    c.description as curr_description,
    p.category_id as prev_category_id,
    c.category_id as curr_category_id,
    p.subcategory_id as prev_subcategory_id,
    c.subcategory_id as curr_subcategory_id,
    case
      when p.source_id is null then 'added'
      when c.source_id is null then 'removed'
      when p.name is distinct from c.name then 'renamed'
      when p.type_name is distinct from c.type_name then 'type_changed'
      when p.description is distinct from c.description then 'description_changed'
      when p.category_id is distinct from c.category_id then 'category_changed'
      when p.subcategory_id is distinct from c.subcategory_id then 'subcategory_changed'
      else 'unchanged'
    end as change_type
  from prev p
  full outer join curr c using (source_id)
)
select *
from joined
where change_type != 'unchanged';
```

### 7.3 `int_lightcast__skill_diff_summary.sql`

```sql
select change_type, count(*) as cnt
from {{ ref('int_lightcast__skill_diff') }}
group by 1
order by 1;
```

### 7.4 Subcategory capability diff (optional but recommended)

* Compare distinct `subcategory_id` between batches
* Report added/removed/renamed subcategories (if name changed)

---

## 8. Tests (including version-update safety)

### 8.1 Raw / batch integrity

1. **Exactly one current batch exists**

* Enforced by `uq_lightcast_current_batch` partial unique index.

2. **Current batch has skills**

* `count(*) > 0` in `raw.lightcast_skills` for current batch.

3. **Batch counts correct**

* `raw.lightcast_import_batches.skill_count` equals count of `raw.lightcast_skills` for that batch.

4. **Stable id map has unique skill_id**

* Enforced by `uq_lightcast_skill_id_map_skill_id`.

### 8.2 Staging tests

* `stg_lightcast__skills.skill_id` not_null
* `stg_lightcast__skills.skill_type` accepted (`hard`, `soft`)
* `stg_lightcast__skill_synonyms` unique (`skill_id`, `synonym`)
* `stg_lightcast__skill_sources` unique (`skill_id`, `source`)
* `stg_lightcast__capabilities` unique (`capability_id`)
* `stg_lightcast__capability_skills` unique (`capability_id`, `skill_id`)
* `stg_lightcast__capability_skills.weight` between 0 and 1

### 8.3 Marts-level tests

* Every served skill (`published`,`deprecated`) has at least one preferred synonym
* All capability_skill rows reference existing skills and capabilities

---

## 9. Runbook (including updates)

### 9.1 First-time import

1. Place files:

   * `data/lightcast/lightcast_<version>.json`
   * `data/lightcast/import_meta.json`

2. Load raw:

```bash
uv run python scripts/load_lightcast.py \
  --meta data/lightcast/import_meta.json
```

3. Transform + test:

```bash
uv run dbt run
uv run dbt test
```

4. Review changes (initial load will have no previous batch):

* `select * from int_lightcast__skill_diff_summary;`

### 9.2 Version update (new Lightcast release)

1. Add new file:

   * `data/lightcast/lightcast_v9.41.json`
2. Update `import_meta.json` with `"version": "v9.41"`, `"filename": "lightcast_v9.41.json"`
3. Load raw (creates new batch, sets current, keeps history):

```bash
uv run python scripts/load_lightcast.py \
  --meta data/lightcast/import_meta.json
```

4. Transform + test:

```bash
uv run dbt run
uv run dbt test
```

5. Review diffs:

* `select * from int_lightcast__skill_diff_summary;`
* spot check renames / description changes / subcategory changes if needed

---

## 10. Deliverables

* Raw tables:

  * `raw.lightcast_import_batches`
  * `raw.lightcast_skill_id_map`
  * `raw.lightcast_skills`
  * `raw.lightcast_attributions`
* Loader:

  * `scripts/load_lightcast.py` (streaming parse, batch inserts, stable id map, versioned batches, diff summary)
* dbt:

  * macro `lightcast_current_batch_id`
  * Lightcast staging models (skills, synonyms, sources, capabilities, capability_skills, capability_sources)
  * Lightcast diff models (skill diff + summary; optional capability diff)
  * intermediate merge models updated to include Lightcast
* tests for:

  * current batch integrity
  * stable id mapping uniqueness
  * staging/marts referential and uniqueness constraints
