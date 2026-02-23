with source as (

    select * from {{ source('seeds', 'capability_sources') }}

)

select
    trim(capability_id)::text   as capability_id,
    lower(trim(source))::text   as source,
    trim(source_id)::text       as source_id,
    imported_at
from source
