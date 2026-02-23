select
    from_skill_id,
    to_skill_id,
    reason,
    created_at
from {{ ref('int_skill_redirects_merged') }}
