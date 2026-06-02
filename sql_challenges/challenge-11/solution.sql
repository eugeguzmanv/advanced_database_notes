--------------------------------------------------------------------------------
------ Exercise 1: Team Velocity
--------------------------------------------------------------------------------

WITH team_metrics AS (
    SELECT
        t.name AS team_name,
        SUM(CASE WHEN task.status = 'completed' THEN 1 ELSE 0 END) AS completed_tasks,
        COUNT(DISTINCT u.id) AS team_members,
        ROUND(
            SUM(CASE WHEN task.status = 'completed' THEN 1 ELSE 0 END) / 
            NULLIF(COUNT(DISTINCT u.id), 0), 
            2
        ) AS velocity
    FROM teams t
    LEFT JOIN users u 
        ON t.id = u.team_id
    LEFT JOIN tasks task 
        ON u.id = task.assigned_to
    GROUP BY t.id, t.name
)
SELECT 
    team_name,
    completed_tasks,
    team_members,
    NVL(velocity, 0) AS velocity,
    CASE 
        WHEN velocity < 1 OR velocity IS NULL THEN 'Below Average'
        ELSE 'Average or Above'
    END AS velocity_flag
FROM team_metrics
ORDER BY velocity DESC NULLS LAST;


--------------------------------------------------------------------------------
----------------- Exercise 2: On-Time Delivery Rate
--------------------------------------------------------------------------------
SELECT
    priority,
    COUNT(*) AS total_completed_tasks,
    SUM(CASE WHEN completed_at <= due_date THEN 1 ELSE 0 END) AS on_time_tasks,
    ROUND(
        (SUM(CASE WHEN completed_at <= due_date THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(COUNT(*), 0),
        2
    ) AS on_time_delivery_rate,
    ROUND(
        AVG(
            CASE 
                WHEN completed_at > due_date 
                -- Direct structural arithmetic subtraction to preserve exact fractional day hours
                THEN (completed_at - due_date) * 24 
            END
        ),
        2
    ) AS avg_late_hours
FROM tasks
WHERE status = 'completed'
  AND due_date IS NOT NULL
  AND completed_at IS NOT NULL
GROUP BY priority
ORDER BY
    CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high'     THEN 2
        WHEN 'medium'   THEN 3
        WHEN 'low'      THEN 4
        ELSE 5
    END;


--------------------------------------------------------------------------------
-------------- Exercise 3: Improve "Tasks per Team" (KPI 2 from class)
--------------------------------------------------------------------------------

SELECT
    t.name AS team_name,
    COUNT(ts.id) AS total_tasks,
    SUM(CASE WHEN ts.status IN ('open', 'in_progress', 'blocked') THEN 1 ELSE 0 END) AS active_tasks,
    ROUND(
        SUM(CASE WHEN ts.status = 'completed' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(SUM(CASE WHEN ts.status != 'cancelled' THEN 1 ELSE 0 END), 0),
        2
    ) AS completion_rate,
    CASE
        WHEN SUM(CASE WHEN ts.status IN ('open', 'in_progress', 'blocked') THEN 1 ELSE 0 END) > 10 
            THEN 'Overloaded'
        WHEN SUM(CASE WHEN ts.status IN ('open', 'in_progress', 'blocked') THEN 1 ELSE 0 END) BETWEEN 5 AND 10 
            THEN 'Healthy'
        ELSE 'Underutilized'
    END AS health_score
FROM teams t
LEFT JOIN users u 
    ON u.team_id = t.id
LEFT JOIN tasks ts 
    ON ts.assigned_to = u.id
GROUP BY t.id, t.name
ORDER BY active_tasks DESC;


--------------------------------------------------------------------------------
-------------- Exercise 4: Improve "Average Resolution Time" (KPI 5 from class)
--------------------------------------------------------------------------------

WITH resolution_metrics AS (
    SELECT
        priority,
        COUNT(*) AS completed_task_count,
        ROUND(AVG((completed_at - created_at) * 24), 2) AS avg_resolution_hours,
        ROUND(
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (completed_at - created_at) * 24), 
            2
        ) AS median_resolution_hours,
        ROUND(MIN((completed_at - created_at) * 24), 2) AS fastest_resolution_hours,
        ROUND(MAX((completed_at - created_at) * 24), 2) AS slowest_resolution_hours
    FROM tasks
    WHERE status = 'completed'
      AND completed_at IS NOT NULL
      AND created_at IS NOT NULL
    GROUP BY priority
)
SELECT
    priority,
    completed_task_count,
    avg_resolution_hours,
    median_resolution_hours,
    fastest_resolution_hours,
    slowest_resolution_hours,
    CASE
        WHEN priority = 'critical' AND avg_resolution_hours <= 24  THEN 'Target Met'
        WHEN priority = 'high'     AND avg_resolution_hours <= 72  THEN 'Target Met'
        WHEN priority = 'medium'   AND avg_resolution_hours <= 168 THEN 'Target Met'
        WHEN priority = 'low'      AND avg_resolution_hours <= 336 THEN 'Target Met'
        ELSE 'Target Missed'
    END AS target_sla_status
FROM resolution_metrics
ORDER BY
    CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high'     THEN 2
        WHEN 'medium'   THEN 3
        WHEN 'low'      THEN 4
        ELSE 5
    END;


--------------------------------------------------------------------------------
--------------- Exercise 5: Improve "Overdue Tasks"
--------------------------------------------------------------------------------

WITH overdue_base AS (
    SELECT
        ts.title AS task_title,
        u.full_name AS assignee,
        t.name AS team_name,
        ts.priority,
        ts.due_date,
        (TRUNC(SYSDATE) - TRUNC(ts.due_date)) AS days_overdue
    FROM tasks ts
    LEFT JOIN users u  ON ts.assigned_to = u.id
    LEFT JOIN teams t  ON u.team_id = t.id
    WHERE ts.due_date < TRUNC(SYSDATE)
      AND ts.status NOT IN ('completed', 'cancelled')
      AND ts.due_date IS NOT NULL
)
SELECT
    task_title,
    assignee,
    team_name,
    priority,
    due_date,
    days_overdue,
    CASE
        WHEN priority = 'critical' AND days_overdue > 0 THEN 'CRITICAL'[cite: 2]
        WHEN priority = 'high'     AND days_overdue > 2 THEN 'HIGH'[cite: 2]
        WHEN priority = 'medium'   AND days_overdue > 5 THEN 'MEDIUM'[cite: 2]
        ELSE 'LOW'[cite: 2]
    END AS severity
FROM overdue_base
ORDER BY
    CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high'     THEN 2
        WHEN 'medium'   THEN 3
        ELSE 4
    END,
    days_overdue DESC;


-- SUMMARY REPORT BY SEVERITY

WITH summary_base AS (
    SELECT
        (TRUNC(SYSDATE) - TRUNC(ts.due_date)) AS days_overdue,
        CASE
            WHEN ts.priority = 'critical' AND (TRUNC(SYSDATE) - TRUNC(ts.due_date)) > 0 THEN 'CRITICAL'[cite: 2]
            WHEN ts.priority = 'high'     AND (TRUNC(SYSDATE) - TRUNC(ts.due_date)) > 2 THEN 'HIGH'[cite: 2]
            WHEN ts.priority = 'medium'   AND (TRUNC(SYSDATE) - TRUNC(ts.due_date)) > 5 THEN 'MEDIUM'[cite: 2]
            ELSE 'LOW'[cite: 2]
        END AS severity
    FROM tasks ts
    WHERE ts.due_date < TRUNC(SYSDATE)
      AND ts.status NOT IN ('completed', 'cancelled')
      AND ts.due_date IS NOT NULL
)
SELECT
    severity,
    COUNT(*) AS overdue_task_count,
    ROUND(AVG(days_overdue), 2) AS avg_days_overdue
FROM summary_base
GROUP BY severity
ORDER BY
    CASE severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH'     THEN 2
        WHEN 'MEDIUM'   THEN 3
        ELSE 4
    END;


--------------------------------------------------------------------------------
----------- Exercise 6: Fix the Productivity Score
--------------------------------------------------------------------------------

SELECT
    u.id AS user_id,
    u.full_name,
    COUNT(ts.id) AS completed_tasks,
    SUM(
        CASE
            WHEN ts.priority = 'critical' THEN 4[cite: 1, 4]
            WHEN ts.priority = 'high'     THEN 3[cite: 1, 4]
            WHEN ts.priority = 'medium'   THEN 2[cite: 1, 4]
            WHEN ts.priority = 'low'      THEN 1[cite: 1, 4]
            ELSE 0
        END
    ) AS raw_weighted_points,
    ROUND(
        SUM(
            CASE
                WHEN ts.priority = 'critical' THEN 4[cite: 1, 4]
                WHEN ts.priority = 'high'     THEN 3[cite: 1, 4]
                WHEN ts.priority = 'medium'   THEN 2[cite: 1, 4]
                WHEN ts.priority = 'low'      THEN 1[cite: 1, 4]
                ELSE 0
            END
        ) / NULLIF(MAX(TRUNC(ts.completed_at)) - MIN(TRUNC(ts.completed_at)) + 1, 0), -- Normalized[cite: 1]
        2
    ) AS normalized_daily_productivity_score
FROM users u
LEFT JOIN tasks ts 
    ON ts.assigned_to = u.id 
    AND ts.status = 'completed'
    AND ts.completed_at IS NOT NULL
GROUP BY u.id, u.full_name
ORDER BY normalized_daily_productivity_score DESC NULLS LAST;


--------------------------------------------------------------------------------
------------- Exercise 7: Fix the "Team Efficiency"
--------------------------------------------------------------------------------

SELECT
    t.id AS team_id,
    t.name AS team_name,
    COUNT(ts.id) AS aggregate_tasks_logged,
    SUM(CASE WHEN ts.status = 'completed' THEN 1 ELSE 0 END) AS completed_tasks,
    SUM(CASE WHEN ts.status != 'cancelled' THEN 1 ELSE 0 END) AS total_non_cancelled_tasks,
    ROUND(
        (SUM(CASE WHEN ts.status = 'completed' THEN 1 ELSE 0 END) * 100.0) /
        NULLIF(SUM(CASE WHEN ts.status != 'cancelled' THEN 1 ELSE 0 END), 0), -- True contract constraint alignment[cite: 1, 5]
        2
    ) AS team_efficiency_rate
FROM teams t
LEFT JOIN users u 
    ON u.team_id = t.id
LEFT JOIN tasks ts 
    ON ts.assigned_to = u.id
GROUP BY t.id, t.name
ORDER BY team_efficiency_rate DESC NULLS LAST;


--------------------------------------------------------------------------------
------------ Exercise 8: Fix the "Urgency Index"
--------------------------------------------------------------------------------

SELECT
    title,
    priority,
    due_date,
    (TRUNC(due_date) - TRUNC(SYSDATE)) AS days_until_due,
    CASE
        WHEN priority = 'critical' THEN 4[cite: 1, 5]
        WHEN priority = 'high'     THEN 3[cite: 1, 5]
        WHEN priority = 'medium'   THEN 2[cite: 1, 5]
        WHEN priority = 'low'      THEN 1[cite: 1, 5]
        ELSE 0
    END AS priority_weight,
    (
        CASE
            WHEN priority = 'critical' THEN 40
            WHEN priority = 'high'     THEN 30
            WHEN priority = 'medium'   THEN 20
            WHEN priority = 'low'      THEN 10
            ELSE 0
        END 
        - 
        (TRUNC(due_date) - TRUNC(SYSDATE))
    ) AS urgency_score
FROM tasks
WHERE status NOT IN ('completed', 'cancelled')
  AND due_date IS NOT NULL
ORDER BY urgency_score DESC;