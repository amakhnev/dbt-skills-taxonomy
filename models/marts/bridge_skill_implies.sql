select
    from_skill_id,
    to_skill_id,
    strength,
    source,
    lifecycle_state,
    created_at,
    updated_at
from {{ ref('stg_skill_implies') }}
