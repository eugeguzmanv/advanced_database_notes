WITH ranking AS(
SELECT name, salary, department_id, RANK() OVER (
PARTITION BY department_id ORDER BY salary DESC) AS dept_rank
FROM employee
) 

SELECT d.department_name, r.name, r.salary FROM ranks AS r
INNER JOIN department AS d
ON d.department_id = r.department_id
WHERE r.ranking <= 3
ORDER BY d.department_name ASC, r.salary DESC, r.name DESC;