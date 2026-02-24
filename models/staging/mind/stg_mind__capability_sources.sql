{#
  Source traceability for both domain and concept capabilities.
#}

with skills as (
    select
        payload,
        imported_at
    from {{ source('mind', 'mind_skills') }}
),

-- Domain capabilities
domains as (
    select
        trim(dom.value::text, '"') as domain_name,
        min(skills.imported_at) as imported_at
    from skills,
        jsonb_array_elements(skills.payload -> 'technicalDomains') as dom (value)
    where trim(dom.value::text, '"') != ''
    group by 1
),

domain_sources as (
    select
        {{ slugify('domain_name') }} as capability_id,
        'mind' as source,
        domain_name as source_id,
        imported_at
    from domains
),

-- Concept capabilities
concepts as (
    select
        name,
        imported_at
    from {{ source('mind', 'mind_concepts') }}
),

concept_sources as (
    select
        {{ slugify('name') }} as capability_id,
        'mind' as source,
        name as source_id,
        imported_at
    from concepts
),

unioned as (
    select * from domain_sources
    union all
    select * from concept_sources
),

-- Deduplicate: domain (published) wins over concept (draft)
deduped as (
    select
        capability_id,
        source,
        source_id,
        imported_at,
        row_number() over (
            partition by capability_id, source
            order by source_id
        ) as _rn
    from unioned
)

select
    capability_id,
    source,
    source_id,
    imported_at
from deduped
where _rn = 1
