{% macro create_lightcast_raw_tables() %}
  {% set ddl %}

    CREATE SCHEMA IF NOT EXISTS raw;

    CREATE TABLE IF NOT EXISTS raw.lightcast_import_batches (
        import_batch_id      text PRIMARY KEY,
        version_label        text NOT NULL,
        file_path            text NOT NULL,
        file_sha256          text NOT NULL,
        imported_at          timestamptz NOT NULL DEFAULT now(),
        skill_count          integer NOT NULL DEFAULT 0,
        attribution_count    integer NOT NULL DEFAULT 0,
        is_current           boolean NOT NULL DEFAULT false,
        previous_batch_id    text
    );

    CREATE UNIQUE INDEX IF NOT EXISTS uq_lightcast_current_batch
        ON raw.lightcast_import_batches(is_current) WHERE is_current = true;

    CREATE TABLE IF NOT EXISTS raw.lightcast_skill_id_map (
        source_id        text PRIMARY KEY,
        skill_id         text NOT NULL,
        first_seen_at    timestamptz NOT NULL DEFAULT now(),
        last_seen_at     timestamptz NOT NULL DEFAULT now(),
        first_name       text NOT NULL,
        last_name        text NOT NULL
    );

    CREATE UNIQUE INDEX IF NOT EXISTS uq_lightcast_skill_id_map_skill_id
        ON raw.lightcast_skill_id_map(skill_id);

    CREATE TABLE IF NOT EXISTS raw.lightcast_skills (
        import_batch_id     text NOT NULL REFERENCES raw.lightcast_import_batches(import_batch_id),
        source_id           text NOT NULL,
        skill_id            text NOT NULL,
        name                text NOT NULL,
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
        payload             jsonb NOT NULL,
        imported_at         timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (import_batch_id, source_id)
    );

    CREATE INDEX IF NOT EXISTS idx_lightcast_skills_batch
        ON raw.lightcast_skills(import_batch_id);

    CREATE INDEX IF NOT EXISTS idx_lightcast_skills_skill_id
        ON raw.lightcast_skills(skill_id);

    CREATE INDEX IF NOT EXISTS idx_lightcast_skills_subcategory
        ON raw.lightcast_skills(subcategory_id);

    CREATE TABLE IF NOT EXISTS raw.lightcast_attributions (
        import_batch_id  text NOT NULL REFERENCES raw.lightcast_import_batches(import_batch_id),
        name             text NOT NULL,
        text             text NOT NULL,
        imported_at      timestamptz NOT NULL DEFAULT now()
    );

    CREATE INDEX IF NOT EXISTS idx_lightcast_attr_batch
        ON raw.lightcast_attributions(import_batch_id);

  {% endset %}

  {% do run_query(ddl) %}
  {{ log("Lightcast raw tables created successfully.", info=True) }}

{% endmacro %}
