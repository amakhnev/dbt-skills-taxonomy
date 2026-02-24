-- Depublish candidates: capabilities (any lifecycle state) that have
-- ZERO skills linked to them. These are empty shells that add noise
-- without providing value.

select
    c.capability_id,
    c.name,
    c.group_name,
    c.lifecycle_state,
    csrc.source
from {{ ref('int_capabilities_merged') }} as c
left join {{ ref('int_capability_skills_merged') }} as cs
    using (capability_id)
left join {{ ref('int_capability_sources_merged') }} as csrc
    using (capability_id)
where cs.capability_id is null
order by c.lifecycle_state, c.name
