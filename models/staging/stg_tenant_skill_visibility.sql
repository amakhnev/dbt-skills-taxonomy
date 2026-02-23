with source as (

    select * from {{ source('seeds', 'seed_tenant_skill_visibility') }}

)

select
    trim(tenant_id)::text              as tenant_id,
    trim(skill_id)::text               as skill_id,
    lower(trim(visibility_state))::text as visibility_state,
    updated_at,
    trim(updated_by)::text             as updated_by
from source
