with example as (

    select * from {{ ref('stg_example__capability_sources') }}

),

lightcast as (

    select * from {{ ref('stg_lightcast__capability_sources') }}

),

mind as (

    select * from {{ ref('stg_mind__capability_sources') }}

),

unioned as (

    select * from example
    union all
    select * from lightcast
    union all
    select * from mind

)

select
    capability_id,
    source,
    source_id,
    min(imported_at) as imported_at
from unioned
group by capability_id, source, source_id
