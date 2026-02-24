with src as (
    select
        name,
        payload
    from {{ source('mind', 'mind_skills') }}
),

-- Explode synonyms array
from_array as (
    select
        {{ slugify('src.name') }} as skill_id,
        lower(trim(src.name)) as canonical_name,
        lower(trim(syn.value::text, '"')) as synonym
    from src,
        jsonb_array_elements(src.payload -> 'synonyms') as syn (value)  -- noqa: RF04
    where trim(syn.value::text, '"') != ''
),

-- Always add canonical name as a synonym (ensures preferred exists)
canonical as (
    select
        {{ slugify('src.name') }} as skill_id,
        lower(trim(src.name)) as canonical_name,
        lower(trim(src.name)) as synonym
    from src
),

combined as (
    select
        skill_id,
        canonical_name,
        synonym
    from from_array
    union
    select
        skill_id,
        canonical_name,
        synonym
    from canonical
)

select
    skill_id,
    synonym,
    bool_or(synonym = canonical_name) as is_preferred,
    'mind' as source
from combined
group by skill_id, synonym
