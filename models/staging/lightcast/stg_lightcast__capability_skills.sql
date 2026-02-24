with src as (
  select
    skill_id,
    subcategory_id,
    subcategory_name
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
    and subcategory_id is not null
)

select
  {{ slugify('subcategory_name') }} as capability_id,
  skill_id,
  cast(1.00 as numeric(3,2)) as weight,
  'lightcast' as source
from src
