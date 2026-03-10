1. select colour from my_brick_collection
union
select colour from your_brick_collection
order by colour;

2. select shape from my_brick_collection
union all
select shape from your_brick_collection
order  by shape;

3. select shape from my_brick_collection
minus
select shape from your_brick_collection;

4. select colour from my_brick_collection
INTERSECT
select colour from your_brick_collection
order  by colour;




