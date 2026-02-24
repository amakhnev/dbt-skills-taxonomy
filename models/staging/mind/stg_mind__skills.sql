with src as (
    select
        name,
        payload,
        imported_at
    from {{ source('mind', 'mind_skills') }}
),

slugged as (
    select
        {{ slugify('name') }} as skill_id,
        name,
        cast(null as text) as description,
        'hard' as skill_type,
        'published' as lifecycle_state,
        imported_at as created_at,
        imported_at as updated_at,
        'mind' as source,
        row_number() over (
            partition by {{ slugify('name') }}
            order by name
        ) as _rn
    from src
)

select
    skill_id,
    name,
    description,
    skill_type,
    lifecycle_state,
    created_at,
    updated_at,
    source
from slugged
where _rn = 1
