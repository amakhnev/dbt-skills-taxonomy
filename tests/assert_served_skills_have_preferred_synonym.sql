-- PRD-02 Section 12: served skills (published/deprecated) must have
-- at least one is_preferred=true synonym.
select
    s.skill_id,
    s.name
from {{ ref('dim_skills') }} as s
left join {{ ref('dim_skill_synonyms') }} as syn
    on
        s.skill_id = syn.skill_id
        and syn.is_preferred = true
where
    s.lifecycle_state in ('published', 'deprecated')
    and syn.skill_id is null
