-- Capability skill weights must be between 0 and 1
select
    capability_id,
    skill_id,
    weight
from {{ ref('bridge_capability_skills') }}
where weight < 0 or weight > 1
