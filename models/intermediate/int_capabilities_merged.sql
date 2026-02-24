with example as (

    select * from {{ ref('stg_example__capabilities') }}

),

lightcast as (

    select
        capability_id, name, description, group_name,
        lifecycle_state, created_at, updated_at
    from {{ ref('stg_lightcast__capabilities') }}

)

select * from example
union all
select * from lightcast
