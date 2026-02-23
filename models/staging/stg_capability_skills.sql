with source as (

    select * from {{ source('seeds', 'capability_skills') }}

)

select
    trim(capability_id)::text   as capability_id,
    trim(skill_id)::text        as skill_id,
    weight::numeric(3,2)        as weight,
    lower(trim(source))::text   as source
from source
