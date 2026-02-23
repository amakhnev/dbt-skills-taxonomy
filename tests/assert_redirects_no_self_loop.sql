-- PRD-02 Section 7.3: from_skill_id != to_skill_id
-- Fails if any redirect points to itself.
select
    from_skill_id,
    to_skill_id
from {{ ref('dim_skill_redirects') }}
where from_skill_id = to_skill_id
