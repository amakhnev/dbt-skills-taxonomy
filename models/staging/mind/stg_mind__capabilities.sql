{#
  Two sources of capabilities from MIND:
  1. Technical domains (from skills' technicalDomains[]) - published
  2. Concepts (from __aggregated_concepts.json) - draft
#}

with skills as (
    select
        payload,
        imported_at
    from {{ source('mind', 'mind_skills') }}
),

-- 1. Domain capabilities (published)
domains as (
    select distinct
        trim(dom.value::text, '"') as domain_name,
        min(imported_at) as imported_at
    from skills,
        jsonb_array_elements(payload -> 'technicalDomains') as dom (value)
    where trim(dom.value::text, '"') != ''
    group by 1
),

domain_capabilities as (
    select
        {{ slugify('domain_name') }} as capability_id,
        domain_name as name,
        null::text as description,
        'MIND Technical Domains' as group_name,
        'published' as lifecycle_state,
        imported_at as created_at,
        imported_at as updated_at,
        'mind' as source
    from domains
),

-- 2. Concept capabilities (draft)
concepts as (
    select
        name,
        payload,
        imported_at
    from {{ source('mind', 'mind_concepts') }}
),

concept_capabilities as (
    select
        {{ slugify('name') }} as capability_id,
        name,
        null::text as description,
        array_to_string(
            array(select jsonb_array_elements_text(payload -> 'category')),
            ' | '
        ) as group_name,
        'draft' as lifecycle_state,
        imported_at as created_at,
        imported_at as updated_at,
        'mind' as source
    from concepts
),

unioned as (
    select * from domain_capabilities
    union all
    select * from concept_capabilities
),

-- Deduplicate: published (domain) wins over draft (concept)
ranked as (
    select
        *,
        row_number() over (
            partition by capability_id
            order by
                case lifecycle_state
                    when 'published' then 1
                    when 'draft' then 2
                    else 3
                end
        ) as _rn
    from unioned
)

select
    capability_id,
    name,
    description,
    group_name,
    lifecycle_state,
    created_at,
    updated_at,
    source
from ranked
where _rn = 1
