-- Implication edges must not be self-loops: from_skill_id != to_skill_id
select
    from_skill_id,
    to_skill_id
from {{ ref('bridge_skill_implies') }}
where from_skill_id = to_skill_id
