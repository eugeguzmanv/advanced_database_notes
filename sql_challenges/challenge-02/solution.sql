1. SELECT movies.title, bo.Domestic_sales, bo.International_sales FROM movies INNER JOIN Boxoffice AS bo
    WHERE movies.id = bo.Movie_id;

2. SELECT movies.title, bo.Domestic_sales, bo.International_sales FROM movies INNER JOIN Boxoffice AS bo
    WHERE movies.id = bo.Movie_id AND bo.International_sales > bo.Domestic_sales;

3. SELECT movies.title, bo.Rating FROM movies 
    INNER JOIN Boxoffice AS bo
    WHERE movies.id = bo.Movie_id ORDER BY bo.Rating DESC;
