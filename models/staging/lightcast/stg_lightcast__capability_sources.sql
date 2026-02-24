with src as (
    select distinct
        subcategory_id,
        subcategory_name,
        imported_at
    from {{ source('raw', 'lightcast_skills') }}
    where
        import_batch_id = {{ lightcast_current_batch_id() }}
        and subcategory_id is not null
)

select
    {{ slugify('subcategory_name') }} as capability_id,
    'lightcast' as source,
    cast(subcategory_id as text) as source_id,
    min(imported_at) as imported_at
from src
group by 1, 2, 3
