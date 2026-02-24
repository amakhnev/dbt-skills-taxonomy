with src as (
    select distinct
        subcategory_id,
        subcategory_name,
        category_name,
        imported_at
    from {{ source('raw', 'lightcast_skills') }}
    where
        import_batch_id = {{ lightcast_current_batch_id() }}
        and subcategory_id is not null
)

select
    {{ slugify('subcategory_name') }} as capability_id,
    subcategory_name as name,
    cast(null as text) as description,
    category_name as group_name,
    'published' as lifecycle_state,
    min(imported_at) as created_at,
    max(imported_at) as updated_at,
    'lightcast' as source,
    cast(subcategory_id as text) as lightcast_subcategory_source_id
from src
group by 1, 2, 3, 4, 5, 8, 9
