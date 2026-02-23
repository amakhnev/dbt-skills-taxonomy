with source as (

    select * from {{ source('example', 'skill_redirects') }}

)

select
    lower(trim(from_skill_id))::text as from_skill_id,
    lower(trim(to_skill_id))::text as to_skill_id,
    lower(trim(reason))::text as reason,
    created_at
from source
