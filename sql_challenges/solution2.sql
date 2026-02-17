1. SELECT DISTINCT buildings.building_name FROM buildings
    JOIN employees
    WHERE employees.building = buildings.building_name;

2. SELECT * FROM buildings;

3. SELECT DISTINCT buildings.building_name, employees.role FROM buildings
    LEFT JOIN employees ON employees.building = buildings.building_name;
    