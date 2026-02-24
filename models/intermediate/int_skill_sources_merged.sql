with example as (

    select * from {{ ref('stg_example__skill_sources') }}

),

lightcast as (

    select * from {{ ref('stg_lightcast__skill_sources') }}

),

mind as (

    select * from {{ ref('stg_mind__skill_sources') }}

),

unioned as (

    select * from example
    union all
    select * from lightcast
    union all
    select * from mind

),

deduped as (

    select
        *,
        row_number() over (
            partition by skill_id, source
            order by imported_at
        ) as _rn
    from unioned

)

select
    skill_id,
    source,
    source_id,
    source_uri,
    imported_at
from deduped
where _rn = 1
