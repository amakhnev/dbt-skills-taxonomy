with example as (

    select * from {{ ref('stg_example__capability_skills') }}

),

lightcast as (

    select * from {{ ref('stg_lightcast__capability_skills') }}

)

select * from example
union all
select * from lightcast
