with example as (

    select * from {{ ref('stg_example__capability_sources') }}

)

select * from example
