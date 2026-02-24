with example as (

    select * from {{ ref('stg_example__skill_sources') }}

),

lightcast as (

    select * from {{ ref('stg_lightcast__skill_sources') }}

)

select * from example
union all
select * from lightcast
