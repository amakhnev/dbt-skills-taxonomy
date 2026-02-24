with example as (

    select * from {{ ref('stg_example__skill_implies') }}

),

mind as (

    select * from {{ ref('stg_mind__skill_implies') }}

)

select * from example
union all
select * from mind
