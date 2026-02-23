-- PRD-02 Section 7.4: strength between 0 and 1
-- Fails if any implication strength is out of range.
select
    from_skill_id,
    to_skill_id,
    strength
from {{ ref('bridge_skill_implies') }}
where strength < 0 or strength > 1
