select
    skill_id,
    synonym,
    is_preferred,
    source
from {{ ref('int_skill_synonyms_merged') }}
