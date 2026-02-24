with example as (

    select * from {{ ref('stg_example__capability_skills') }}

),

lightcast as (

    select * from {{ ref('stg_lightcast__capability_skills') }}

),

mind as (

    select * from {{ ref('stg_mind__capability_skills') }}

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
    skill_id,
    max(weight) as weight,
    min(source) as source
from unioned
group by capability_id, skill_id
