select
    capability_id,
    source,
    source_id,
    imported_at
from {{ ref('stg_capability_sources') }}
