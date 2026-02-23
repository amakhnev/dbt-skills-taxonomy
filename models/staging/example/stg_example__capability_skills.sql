with source as (

    select * from {{ source('example', 'capability_skills') }}

)

select
    lower(trim(capability_id))::text as capability_id,
    lower(trim(skill_id))::text as skill_id,
    weight::numeric(3, 2) as weight,
    lower(trim(source))::text as source
from source
