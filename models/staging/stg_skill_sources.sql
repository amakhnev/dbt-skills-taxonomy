with source as (

    select * from {{ source('seeds', 'skill_sources') }}

)

select
    trim(skill_id)::text        as skill_id,
    lower(trim(source))::text   as source,
    trim(source_id)::text       as source_id,
    trim(source_uri)::text      as source_uri,
    imported_at
from source
