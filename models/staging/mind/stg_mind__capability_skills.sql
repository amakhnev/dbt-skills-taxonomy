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
        {{ slugify('skills.name') }} as skill_id,
        0.50 as weight
    from skills,
        jsonb_array_elements(skills.payload -> 'technicalDomains') as dom (value)  -- noqa: RF04
    where trim(dom.value::text, '"') != ''
),

-- B) Concept membership from multiple relation arrays
concept_refs as (
    select
        skills.name,
        {{ slugify('skills.name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,  -- noqa: RF04
        1.00 as weight
    from skills,
        jsonb_array_elements(skills.payload -> 'solvesApplicationTasks') as ref (value)  -- noqa: RF04
    union all
    select
        skills.name,
        {{ slugify('skills.name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,  -- noqa: RF04
        0.80 as weight
    from skills,
        jsonb_array_elements(skills.payload -> 'associatedToApplicationDomains') as ref (value)  -- noqa: RF04
    union all
    select
        skills.name,
        {{ slugify('skills.name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,  -- noqa: RF04
        0.70 as weight
    from skills,
        jsonb_array_elements(skills.payload -> 'architecturalPatterns') as ref (value)  -- noqa: RF04
    union all
    select
        skills.name,
        {{ slugify('skills.name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,  -- noqa: RF04
        0.70 as weight
    from skills,
        jsonb_array_elements(skills.payload -> 'implementsPatterns') as ref (value)  -- noqa: RF04
    union all
    select
        skills.name,
        {{ slugify('skills.name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,  -- noqa: RF04
        0.60 as weight
    from skills,
        jsonb_array_elements(skills.payload -> 'conceptualAspects') as ref (value)  -- noqa: RF04
    union all
    select
        skills.name,
        {{ slugify('skills.name') }} as skill_id,
        trim(ref.value::text, '"') as concept_name,  -- noqa: RF04
        0.40 as weight
    from skills,
        jsonb_array_elements(skills.payload -> 'impliesKnowingConcepts') as ref (value)  -- noqa: RF04
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
