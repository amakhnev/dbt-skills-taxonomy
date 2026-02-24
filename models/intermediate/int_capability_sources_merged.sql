with example as (

    select * from {{ ref('stg_example__capability_sources') }}

),

lightcast as (

    select * from {{ ref('stg_lightcast__capability_sources') }}

)

select * from example
union all
select * from lightcast
