with example as (

    select * from {{ ref('stg_example__tenant_skill_visibility') }}

)

select * from example
