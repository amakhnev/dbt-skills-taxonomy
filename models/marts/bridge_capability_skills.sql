select
    capability_id,
    skill_id,
    weight,
    source
from {{ ref('int_capability_skills_merged') }}
