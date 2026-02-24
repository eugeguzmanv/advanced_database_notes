1. SELECT *, MAX(Years_employed) AS longest_empoyee FROM Employees;

2. SELECT Role, AVG(Years_employed) AS avg_by_role FROM Employees GROUP BY Role;

3. SELECT Building, SUM(Years_employed) AS employee_years_by_building FROM Employees GROUP BY Building;
