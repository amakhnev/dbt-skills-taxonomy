{#
  Two sources of capability-skill mappings:
  A) Domain membership (technicalDomains[]) - weight 0.50
  B) Concept membership (concept reference arrays) - weights vary by relation type,
     collapsed to max(weight) per (capability_id, skill_id)
#}

with skills as (
    select
        name,
        payload
    from {{ source('mind', 'mind_skills') }}
),

known_concepts as (
    select name
    from {{ source('mind', 'mind_concepts') }}
),

-- A) Domain membership
domain_links as (
    select
        {{ slugify('trim(dom.value::text, \'\"\')') }} as capability_id,
        {{ slugify('name') }} as skill_id,
        0.50 as weight
    from skills,
        jsonb_array_elements(payload -> 'technicalDomains') as dom (value)
    where trim(dom.value::text, '"') != ''
),

-- B) Concept membership from multiple relation arrays
concept_refs as (
    select
        name, {{ slugify('name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,
        1.00 as weight
    from skills, jsonb_array_elements(payload -> 'solvesApplicationTasks') as ref (value)
    union all
    select
        name, {{ slugify('name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,
        0.80 as weight
    from skills, jsonb_array_elements(payload -> 'associatedToApplicationDomains') as ref (value)
    union all
    select
        name, {{ slugify('name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,
        0.70 as weight
    from skills, jsonb_array_elements(payload -> 'architecturalPatterns') as ref (value)
    union all
    select
        name, {{ slugify('name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,
        0.70 as weight
    from skills, jsonb_array_elements(payload -> 'implementsPatterns') as ref (value)
    union all
    select
        name, {{ slugify('name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,
        0.60 as weight
    from skills, jsonb_array_elements(payload -> 'conceptualAspects') as ref (value)
    union all
    select
        name, {{ slugify('name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,
        0.40 as weight
    from skills, jsonb_array_elements(payload -> 'impliesKnowingConcepts') as ref (value)
),

concept_links as (
    select
        {{ slugify('cr.concept_name') }} as capability_id,
        cr.skill_id,
        max(cr.weight) as weight
    from concept_refs as cr
    inner join known_concepts as kc on cr.concept_name = kc.name
    group by 1, 2
),

-- Union and deduplicate
all_links as (
    select
        capability_id,
        skill_id,
        weight
    from domain_links
    union all
    select
        capability_id,
        skill_id,
        weight
    from concept_links
),

deduped as (
    select
        capability_id,
        skill_id,
        max(weight) as weight
    from all_links
    group by 1, 2
)

select
    capability_id,
    skill_id,
    weight::numeric(3, 2) as weight,
    'mind' as source
from deduped
