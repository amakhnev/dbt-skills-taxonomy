with source as (

    select * from {{ source('example', 'skill_implies') }}

)

select
    lower(trim(from_skill_id))::text as from_skill_id,
    lower(trim(to_skill_id))::text as to_skill_id,
    strength::numeric(3, 2) as strength,
    lower(trim(source))::text as source,
    lower(trim(lifecycle_state))::text as lifecycle_state,
    created_at,
    updated_at
from source
