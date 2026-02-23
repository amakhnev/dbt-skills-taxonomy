select
    skill_id,
    source,
    source_id,
    source_uri,
    imported_at
from {{ ref('int_skill_sources_merged') }}
