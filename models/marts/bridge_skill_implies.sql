with implies as (

    select * from {{ ref('int_skill_implies_merged') }}

),

skills as (

    select skill_id from {{ ref('int_skills_merged') }}

)

select
    i.from_skill_id,
    i.to_skill_id,
    i.strength,
    i.source,
    i.lifecycle_state,
    i.created_at,
    i.updated_at
from implies as i
inner join skills as s1 on i.from_skill_id = s1.skill_id
inner join skills as s2 on i.to_skill_id = s2.skill_id
