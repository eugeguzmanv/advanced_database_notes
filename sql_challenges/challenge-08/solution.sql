-- ============================================================
-- Exercise 1 — Find the slow query
--
-- Run this query. Look at the execution plan.
-- Is Oracle using an index? Should it?
-- ============================================================

SELECT * FROM patient_visits WHERE site_id = 3;

-- Questions:
-- a) What scan type do you see? Why? 
--    Full Table Scan (FTS). There is no index on site_id. Even if there were, 
--    Oracle would likely choose an FTS. With only 5 possible values across 100,000 rows, 
--    site_id = 3 returns ~20% of the table. Reading blocks sequentially is faster 
--    than the random I/O of jumping between an index and the table.
--
-- b) site_id has values 1–5. Is this high or low cardinality? 
--    Low cardinality. Selectivity is very poor.
--
-- c) Would adding an index on site_id help? Why or why not? 
--    No. Searching for one site_id grabs too many rows. The combined overhead 
--    of reading the index and the table blocks is slower than reading the table once.


-- ============================================================
-- Exercise 2 — Create an index and see if it helps
--
-- Create an index on visit_date.
-- Then run the range query below and check the plan.
-- ============================================================

-- Step 1: Create the index
CREATE INDEX idx_visit_date ON patient_visits(visit_date);

-- Step 2: Run the range query and check the plan
SELECT * FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 30 AND SYSDATE;

-- Questions:
-- a) Does Oracle use the index for this range? 
--    Yes. A 30-day range out of 730 days is roughly 4,000 rows. This is selective 
--    enough for an INDEX RANGE SCAN. Oracle finds the starting ROWID and follows 
--    the leaf blocks to the end date.
--
-- b) Change the range to the last 7 days. Does the plan change?
--    The scan type remains an INDEX RANGE SCAN, but the "Cost" decreases. 
--    7 days is ~1% of the data. The number of Consistent Gets (blocks read) drops 
--    because the result set is much smaller.
--
-- c) Change to the last 700 days. What happens?
--    Oracle switches back to a TABLE ACCESS FULL. You are asking for 95%+ of the table. 
--    Sequential multi-block reads (FTS) are faster than the random I/O required to 
--    bounce between the index and table for 95,000 rows.
--
-- d) Why does the range size affect whether Oracle uses the index?
--    Indexes require a two-step process: find the ROWID, then fetch the table block. 
--    If the range is small, lookups are fast. If the range is large, the lookups 
--    become a bottleneck, and the Optimizer calculates an FTS is cheaper.


-- ============================================================
-- Exercise 3 — Composite index
--
-- You often query by both patient_id AND visit_date together:
--    WHERE patient_id = 1234 AND visit_date > SYSDATE - 90
--
-- Create the composite index and test the query.
-- ============================================================

CREATE INDEX idx_pv_patient_date ON patient_visits(patient_id, visit_date);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);