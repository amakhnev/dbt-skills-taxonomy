with src as (
  select *
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = {{ lightcast_current_batch_id() }}
)

select
  skill_id,
  name,
  description,
  case
    when type_name = 'Common Skill' then 'soft'
    else 'hard'
  end as skill_type,
  '{{ var("lightcast_default_lifecycle_state", "published") }}' as lifecycle_state,
  imported_at as created_at,
  imported_at as updated_at,
  'lightcast' as source,

  -- diagnostics (not promoted to marts)
  source_id as lightcast_source_id,
  category_id,
  category_name,
  subcategory_id,
  subcategory_name,
  description_source,
  is_software,
  is_language
from src
