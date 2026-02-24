select change_type, count(*) as cnt
from {{ ref('int_lightcast__skill_diff') }}
group by 1
order by 1
