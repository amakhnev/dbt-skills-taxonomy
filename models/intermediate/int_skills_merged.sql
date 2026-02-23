{#
  To add a new source, add a CTE and union it below.
  Example:
    , lightcast as (select * from  ref('stg_lightcast__skills'))
#}

with example as (

    select * from {{ ref('stg_example__skills') }}

)

select * from example
