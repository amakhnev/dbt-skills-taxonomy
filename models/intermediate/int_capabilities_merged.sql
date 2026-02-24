with example as (

    select
        *,
        'example' as _source
    from {{ ref('stg_example__capabilities') }}

),

lightcast as (

    select
        capability_id,
        name,
        description,
        group_name,
        lifecycle_state,
        created_at,
        updated_at,
        'lightcast' as _source
    from {{ ref('stg_lightcast__capabilities') }}

),

mind as (

    select
        capability_id,
        name,
        description,
        group_name,
        lifecycle_state,
        created_at,
        updated_at,
        'mind' as _source
    from {{ ref('stg_mind__capabilities') }}

),

unioned as (

    select * from example
    union all
    select * from lightcast
    union all
    select * from mind

),

ranked as (

    select
        *,
        row_number() over (
            partition by capability_id
            order by
                case _source
                    when 'example' then 1
                    when 'lightcast' then 2
                    when 'mind' then 3
                    else 99
                end,
                case lifecycle_state
                    when 'published' then 1
                    when 'draft' then 2
                    else 3
                end
        ) as _rn
    from unioned

)

select
    capability_id,
    name,
    description,
    group_name,
    lifecycle_state,
    created_at,
    updated_at
from ranked
where _rn = 1
