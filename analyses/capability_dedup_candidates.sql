-- Deduplication candidates: pairs of capabilities whose skill sets overlap
-- significantly. Uses Jaccard similarity (intersection / union) to rank pairs.
-- A score of 1.0 means identical skill sets; 0.5+ is a strong overlap.

with cap_skills as (
    select
        cs.capability_id,
        c.name as capability_name,
        c.lifecycle_state,
        cs.skill_id
    from {{ ref('int_capability_skills_merged') }} as cs
    inner join {{ ref('int_capabilities_merged') }} as c
        using (capability_id)
),

-- Count skills per capability (for the union denominator)
cap_counts as (
    select
        capability_id,
        count(*) as skill_count
    from cap_skills
    group by 1
),

-- Self-join to find overlapping pairs (avoid duplicates with <)
pair_intersection as (
    select
        a.capability_id as cap_a_id,
        b.capability_id as cap_b_id,
        count(*) as shared_skills
    from cap_skills as a
    inner join cap_skills as b
        on a.skill_id = b.skill_id
        and a.capability_id < b.capability_id
    group by 1, 2
),

scored as (
    select
        pi.cap_a_id,
        ca.capability_name as cap_a_name,
        ca_c.skill_count as cap_a_skills,
        ca_cap.lifecycle_state as cap_a_state,
        pi.cap_b_id,
        cb.capability_name as cap_b_name,
        cb_c.skill_count as cap_b_skills,
        cb_cap.lifecycle_state as cap_b_state,
        pi.shared_skills,
        round(
            pi.shared_skills::numeric
            / (ca_c.skill_count + cb_c.skill_count - pi.shared_skills),
            3
        ) as jaccard_similarity
    from pair_intersection as pi
    inner join cap_skills as ca on ca.capability_id = pi.cap_a_id
    inner join cap_skills as cb on cb.capability_id = pi.cap_b_id
    inner join cap_counts as ca_c on ca_c.capability_id = pi.cap_a_id
    inner join cap_counts as cb_c on cb_c.capability_id = pi.cap_b_id
    inner join {{ ref('int_capabilities_merged') }} as ca_cap
        on ca_cap.capability_id = pi.cap_a_id
    inner join {{ ref('int_capabilities_merged') }} as cb_cap
        on cb_cap.capability_id = pi.cap_b_id
)

select distinct
    cap_a_id,
    cap_a_name,
    cap_a_skills,
    cap_a_state,
    cap_b_id,
    cap_b_name,
    cap_b_skills,
    cap_b_state,
    shared_skills,
    jaccard_similarity
from scored
where jaccard_similarity >= 0.3
order by jaccard_similarity desc, shared_skills desc
