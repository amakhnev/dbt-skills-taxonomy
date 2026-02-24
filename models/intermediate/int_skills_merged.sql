{#
  Skills from all sources, deduplicated by skill_id with source priority.
  Priority: manual > lightcast > mind > esco
#}

with example as (

    select
        skill_id, name, description, skill_type,
        lifecycle_state, created_at, updated_at,
        'example' as _source
    from {{ ref('stg_example__skills') }}

),

lightcast as (

    select
        skill_id, name, description, skill_type,
        lifecycle_state, created_at, updated_at,
        'lightcast' as _source
    from {{ ref('stg_lightcast__skills') }}

),

unioned as (

    select * from example
    union all
    select * from lightcast

),

ranked as (

    select
        *,
        row_number() over (
            partition by skill_id
            order by
                case _source
                    when 'example' then 1
                    when 'lightcast' then 2
                    else 99
                end
        ) as _rn
    from unioned

)

select
    skill_id, name, description, skill_type,
    lifecycle_state, created_at, updated_at
from ranked
where _rn = 1
