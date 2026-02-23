select
    tenant_id,
    capability_id,
    visibility_state,
    updated_at,
    updated_by
from {{ ref('stg_tenant_capability_visibility') }}
