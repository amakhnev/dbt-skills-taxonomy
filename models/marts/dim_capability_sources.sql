select
    capability_id,
    source,
    source_id,
    imported_at
from {{ ref('int_capability_sources_merged') }}
