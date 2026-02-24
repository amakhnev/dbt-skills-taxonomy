with batches as (
  select *
  from {{ source('raw', 'lightcast_import_batches') }}
),
current_batch as (
  select import_batch_id, previous_batch_id
  from batches
  where is_current = true
)
select * from current_batch
