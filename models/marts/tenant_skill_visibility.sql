select
    tenant_id,
    skill_id,
    visibility_state,
    updated_at,
    updated_by
from {{ ref('stg_tenant_skill_visibility') }}
