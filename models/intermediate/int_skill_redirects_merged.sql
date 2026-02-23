with example as (

    select * from {{ ref('stg_example__skill_redirects') }}

)

select * from example
