with example as (

    select * from {{ ref('stg_example__capabilities') }}

)

select * from example
