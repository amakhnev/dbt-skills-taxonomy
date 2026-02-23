select
    capability_id,
    name,
    description,
    group_name,
    lifecycle_state,
    created_at,
    updated_at
from {{ ref('int_capabilities_merged') }}
