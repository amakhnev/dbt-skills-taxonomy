select
    skill_id,
    source,
    source_id,
    source_uri,
    imported_at
from {{ ref('stg_skill_sources') }}
