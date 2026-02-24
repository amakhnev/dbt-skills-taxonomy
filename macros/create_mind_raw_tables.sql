{% macro create_mind_raw_tables() %}
  {% set ddl %}

    CREATE SCHEMA IF NOT EXISTS raw;

    CREATE TABLE IF NOT EXISTS raw.mind_skills (
        name          text NOT NULL,
        payload       jsonb NOT NULL,
        import_ref    text,
        imported_at   timestamptz NOT NULL DEFAULT now()
    );

    CREATE UNIQUE INDEX IF NOT EXISTS uq_mind_skills_name
        ON raw.mind_skills(name);

    CREATE TABLE IF NOT EXISTS raw.mind_concepts (
        name          text NOT NULL,
        payload       jsonb NOT NULL,
        import_ref    text,
        imported_at   timestamptz NOT NULL DEFAULT now()
    );

    CREATE UNIQUE INDEX IF NOT EXISTS uq_mind_concepts_name
        ON raw.mind_concepts(name);

  {% endset %}

  {% do run_query(ddl) %}
  {{ log("MIND raw tables created successfully.", info=True) }}

{% endmacro %}
