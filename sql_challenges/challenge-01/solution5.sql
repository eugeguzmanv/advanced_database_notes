1. SELECT city,population from north_american_cities WHERE country = "Canada";
2. SELECT * from north_american_cities WHERE country = "United States" ORDER BY latitude DESC;
3. SELECT * from north_american_cities WHERE longitude < -87.629798 ORDER BY longitude ASC;
4. SELECT * from north_american_cities WHERE country = "Mexico" ORDER BY population DESC LIMIT 2;
5. SELECT city, population from north_american_cities WHERE country = "United States" ORDER BY population DESC LIMIT 2 OFFSET 2;