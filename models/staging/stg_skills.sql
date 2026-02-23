with source as (

    select * from {{ source('seeds', 'skills') }}

)

select
    trim(skill_id)::text          as skill_id,
    trim(name)::text              as name,
    trim(description)::text       as description,
    lower(trim(skill_type))::text as skill_type,
    lower(trim(lifecycle_state))::text as lifecycle_state,
    created_at,
    updated_at
from source
