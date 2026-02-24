1. SELECT COUNT(*) FROM employees WHERE Role = "Artist";

2. SELECT role, COUNT(*) FROM employees GROUP BY role;

3. SELECT role, SUM(years_employed) FROM employees GROUP BY role HAVING role = "Engineer";
    