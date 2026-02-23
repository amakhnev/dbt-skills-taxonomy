with example as (

    select * from {{ ref('stg_example__skill_sources') }}

)

select * from example
