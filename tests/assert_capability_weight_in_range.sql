-- PRD-02 Section 7.6: weight between 0 and 1
-- Fails if any capability-skill weight is out of range.
select
    capability_id,
    skill_id,
    weight
from {{ ref('bridge_capability_skills') }}
where weight < 0 or weight > 1
