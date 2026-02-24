with src as (
  select skill_id, name
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
)

select
  skill_id,
  lower(trim(name)) as synonym,
  true as is_preferred,
  'lightcast' as source
from src
