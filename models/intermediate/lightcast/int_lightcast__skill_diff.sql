with pair as (
  select * from {{ ref('int_lightcast__batch_pair') }}
),
curr as (
  select source_id, name, type_name, description, category_id, subcategory_id
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = (select import_batch_id from pair)
),
prev as (
  select source_id, name, type_name, description, category_id, subcategory_id
  from {{ source('raw', 'lightcast_skills') }}
  where import_batch_id = (select previous_batch_id from pair)
),
joined as (
  select
    coalesce(c.source_id, p.source_id) as source_id,
    p.name as prev_name,
    c.name as curr_name,
    p.type_name as prev_type_name,
    c.type_name as curr_type_name,
    p.description as prev_description,
    c.description as curr_description,
    p.category_id as prev_category_id,
    c.category_id as curr_category_id,
    p.subcategory_id as prev_subcategory_id,
    c.subcategory_id as curr_subcategory_id,
    case
      when p.source_id is null then 'added'
      when c.source_id is null then 'removed'
      when p.name is distinct from c.name then 'renamed'
      when p.type_name is distinct from c.type_name then 'type_changed'
      when p.description is distinct from c.description then 'description_changed'
      when p.category_id is distinct from c.category_id then 'category_changed'
      when p.subcategory_id is distinct from c.subcategory_id then 'subcategory_changed'
      else 'unchanged'
    end as change_type
  from prev p
  full outer join curr c using (source_id)
)
select *
from joined
where change_type != 'unchanged'
