with example as (

    select
        *,
        'example' as _source
    from {{ ref('stg_example__skill_synonyms') }}

),

lightcast as (

    select
        *,
        'lightcast' as _source
    from {{ ref('stg_lightcast__skill_synonyms') }}

),

mind as (

    select
        *,
        'mind' as _source
    from {{ ref('stg_mind__skill_synonyms') }}

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
            partition by skill_id, synonym
            order by
                case _source
                    when 'example' then 1
                    when 'lightcast' then 2
                    when 'mind' then 3
                    else 99
                end
        ) as _rn
    from unioned

)

select
    skill_id,
    synonym,
    is_preferred,
    source
from ranked
where _rn = 1
