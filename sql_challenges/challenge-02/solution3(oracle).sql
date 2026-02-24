1. select COUNT(distinct shape) AS number_of_shapes,
       stddev(distinct weight) AS distinct_weight_stddev
from   bricks;

2. select shape, sum(weight) as shape_weight
from   bricks
group by shape;

3. select shape, sum ( weight )
from   bricks
having sum(weight) < 4
group  by shape;
