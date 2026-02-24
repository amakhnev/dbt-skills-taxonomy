-- Publish candidates: draft capabilities that DO have skills linked to them.
-- Ordered by skill count descending — the more skills a capability covers,
-- the stronger the case for promoting it to published.

select
    c.capability_id,
    c.name,
    c.group_name,
    c.lifecycle_state,
    count(cs.skill_id) as skill_count,
    round(avg(cs.weight), 2) as avg_weight,
    min(cs.weight) as min_weight,
    max(cs.weight) as max_weight
from {{ ref('int_capabilities_merged') }} as c
inner join {{ ref('int_capability_skills_merged') }} as cs
    using (capability_id)
where c.lifecycle_state = 'draft'
group by 1, 2, 3, 4
order by skill_count desc
