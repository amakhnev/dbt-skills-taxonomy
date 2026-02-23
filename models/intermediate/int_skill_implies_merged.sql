with example as (

    select * from {{ ref('stg_example__skill_implies') }}

)

select * from example
