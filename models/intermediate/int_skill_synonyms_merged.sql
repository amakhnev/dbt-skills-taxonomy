with example as (

    select * from {{ ref('stg_example__skill_synonyms') }}

),

lightcast as (

    select * from {{ ref('stg_lightcast__skill_synonyms') }}

)

select * from example
union all
select * from lightcast
