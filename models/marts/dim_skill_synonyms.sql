select
    skill_id,
    synonym,
    is_preferred,
    source
from {{ ref('stg_skill_synonyms') }}
