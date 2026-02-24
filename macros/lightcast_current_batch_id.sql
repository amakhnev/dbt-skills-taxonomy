{% macro lightcast_current_batch_id() %}
(
  select import_batch_id
  from {{ source('raw', 'lightcast_import_batches') }}
  where is_current = true
  limit 1
)
{% endmacro %}
