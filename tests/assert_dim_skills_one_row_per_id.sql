-- Exactly one row per skill_id in dim_skills.
-- Fails if any skill_id appears more than once.
select
    skill_id,
    count(*) as row_count
from {{ ref('dim_skills') }}
group by skill_id
having count(*) > 1
