with source as (

    select * from {{ source('seeds', 'capabilities') }}

)

select
    trim(capability_id)::text          as capability_id,
    trim(name)::text                   as name,
    trim(description)::text            as description,
    trim(group_name)::text             as group_name,
    lower(trim(lifecycle_state))::text as lifecycle_state,
    created_at,
    updated_at
from source
