select
    capability_id,
    skill_id,
    weight,
    source
from {{ ref('stg_capability_skills') }}
