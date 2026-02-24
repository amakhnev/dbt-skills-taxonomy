with src as (
    select
        skill_id,
        source_id,
        info_url,
        imported_at
    from {{ source('raw', 'lightcast_skills') }}
    where import_batch_id = {{ lightcast_current_batch_id() }}
)

select
    skill_id,
    'lightcast' as source,
    source_id,
    info_url as source_uri,
    imported_at
from src
