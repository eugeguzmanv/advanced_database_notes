1. select b.*,
       count(*) over (
         partition by shape
       ) bricks_per_shape,
       median ( weight ) over (
         partition by weight
       ) median_weight_per_shape
from   bricks b
order  by shape, weight, brick_id;

2. select b.brick_id, b.weight,
       round ( avg ( weight ) over (
         order by brick_id
       ), 2 ) running_average_weight
from   bricks b
order  by brick_id;

3. select b.*,
       min ( colour ) over (
         order by brick_id
         rows between 2 preceding and 1 preceding
       ) first_colour_two_prev,
       count (*) over (
         order by weight
         range between current row and 1 following
       ) count_values_this_and_next
from   bricks b
order  by weight;

4. with totals as (
  select b.*,
         sum ( weight ) over (
           partition by b.shape
         ) weight_per_shape,
         sum ( weight ) over (
           order by b.brick_id
         ) running_weight_by_id
  from  bricks b
)
select * from totals
where  totals.weight_per_shape > 4 AND totals.running_weight_by_id > 4
order  by brick_id