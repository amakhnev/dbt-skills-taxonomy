select
    skill_id,
    name,
    description,
    skill_type,
    lifecycle_state,
    created_at,
    updated_at
from {{ ref('stg_skills') }}
