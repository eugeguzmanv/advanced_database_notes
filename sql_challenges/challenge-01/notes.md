You can create a query inside another query, like this: 
SELECT * from north_american_cities WHERE latitude > (select latitude from north_american_cities WHERE city = "Chicago")
