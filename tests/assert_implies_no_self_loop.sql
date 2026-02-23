-- PRD-02 Section 7.4: from_skill_id != to_skill_id
-- Fails if any implication edge is a self-loop.
select
    from_skill_id,
    to_skill_id
from {{ ref('bridge_skill_implies') }}
where from_skill_id = to_skill_id
