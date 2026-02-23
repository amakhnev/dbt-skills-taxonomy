select
    from_skill_id,
    to_skill_id,
    reason,
    created_at
from {{ ref('stg_skill_redirects') }}
