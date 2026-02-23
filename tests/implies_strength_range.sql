-- Implication strength must be between 0 and 1
select
    from_skill_id,
    to_skill_id,
    strength
from {{ ref('bridge_skill_implies') }}
where strength < 0 or strength > 1
