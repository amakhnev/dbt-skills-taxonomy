-- Redirects must not point to themselves: from_skill_id != to_skill_id
select
    from_skill_id,
    to_skill_id
from {{ ref('dim_skill_redirects') }}
where from_skill_id = to_skill_id
