with source as (

    select * from {{ source('example', 'skill_synonyms') }}

)

select
    lower(trim(skill_id))::text as skill_id,
    lower(trim(synonym))::text as synonym,
    is_preferred::boolean as is_preferred,
    lower(trim(source))::text as source
from source
