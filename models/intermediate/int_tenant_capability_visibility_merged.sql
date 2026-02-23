with example as (

    select * from {{ ref('stg_example__tenant_capability_visibility') }}

)

select * from example
