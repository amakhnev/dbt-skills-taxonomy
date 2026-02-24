with src as (
    select
        name,
        imported_at
    from {{ source('mind', 'mind_skills') }}
),

slugged as (
    select
        {{ slugify('name') }} as skill_id,
        'mind' as source,
        name as source_id,
        'https://github.com/MIND-TechAI/MIND-tech-ontology' as source_uri,
        imported_at,
        row_number() over (
            partition by {{ slugify('name') }}
            order by name
        ) as _rn
    from src
)

select
    skill_id,
    source,
    source_id,
    source_uri,
    imported_at
from slugged
where _rn = 1
