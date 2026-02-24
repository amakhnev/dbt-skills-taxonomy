with src as (
    select
        name,
        payload,
        imported_at
    from {{ source('mind', 'mind_skills') }}
),

implies_skills as (
    select
        {{ slugify('src.name') }} as from_skill_id,
        {{ slugify('ref.value::text') }} as to_skill_id,
        0.90 as strength,
        src.imported_at
    from src,
        jsonb_array_elements(src.payload -> 'impliesKnowingSkills') as ref (value)  -- noqa: RF04
),

supported_langs as (
    select
        {{ slugify('src.name') }} as from_skill_id,
        {{ slugify('ref.value::text') }} as to_skill_id,
        0.95 as strength,
        src.imported_at
    from src,
        jsonb_array_elements(src.payload -> 'supportedProgrammingLanguages') as ref (value)  -- noqa: RF04
),

unioned as (
    select * from implies_skills
    union all
    select * from supported_langs
),

deduped as (
    select
        from_skill_id,
        to_skill_id,
        max(strength) as strength,
        min(imported_at) as imported_at
    from unioned
    where from_skill_id != to_skill_id
    group by 1, 2
)

select
    from_skill_id,
    to_skill_id,
    cast(strength as numeric(3, 2)) as strength,
    'mind' as source,
    'published' as lifecycle_state,
    imported_at as created_at,
    imported_at as updated_at
from deduped
