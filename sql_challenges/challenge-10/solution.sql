-- ============================================
-- EXERCISE 1: Explore your schema
-- ============================================
-- List all the objects in your schema using user_objects
-- Group by object_type and count them
-- Which object types do you have? -> Index, Lob, Sequence, Table

SELECT object_type, COUNT(*) AS cnt
FROM user_objects
GROUP BY object_type
ORDER BY object_type;

SELECT object_name, object_type, created, last_ddl_time
FROM user_objects
ORDER BY object_type, object_name;

-- ============================================
-- EXERCISE 2: Basic GET_DDL
-- ============================================
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/

SET LONG 100000
SET PAGESIZE 0

-- Retrieving DDL for all tables
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
ORDER BY table_name;

-- Identified Key Parts in Output:
-- 1. Column definitions: Specifies the column NAME, data TYPE, and NULL/NOT NULL indicators.
-- 2. Constraints: Defines business rules like PRIMARY KEY, FOREIGN KEY (FK), and CHECK constraints.
-- 3. Storage parameters: Indicates physical storage attributes (disabled here via SEGMENT_ATTRIBUTES = false).

-- ============================================
-- EXERCISE 3: Clean DDL for portability
-- ============================================
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'EMIT_SCHEMA', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/

SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
WHERE ROWNUM = 1;

-- Comparison Note:
-- With EMIT_SCHEMA (default): Output hardcodes the owner, e.g., CREATE TABLE "SALES"."ORDERS" ...
-- Without EMIT_SCHEMA: Output is schema-agnostic, e.g., CREATE TABLE "ORDERS" ...

-- ============================================
-- EXERCISE 4: Plan a migration
-- ============================================
-- Identify tables with Foreign Keys
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
WHERE table_name = 'ANY_TABLE_WITH_FK';

-- Check for schema-qualified references
SELECT constraint_name, table_name, r_constraint_name
FROM user_constraints
WHERE constraint_type = 'R';

-- Required Changes: 
-- If foreign key constraints point to other schemas, update the REFERENCES clause 
-- to point to the new schema name or ensure the target table exists in the same schema.

-- Migration Checklist:
-- 1. Export all DDL with EMIT_SCHEMA = false.
-- 2. Review FK constraints for hardcoded schema references.
-- 3. Update constraint references manually if needed.
-- 4. Reload objects in this strict order: Tables -> Constraints -> Indexes -> Views -> Code.

-- ============================================
-- EXERCISE 5: Dependency order
-- ============================================
-- All dependencies in the schema
SELECT referenced_name, referencing_name, referencing_type
FROM user_dependencies
ORDER BY referenced_name;

-- Objects that depend directly on tables
SELECT referencing_name, referencing_type
FROM user_dependencies
WHERE referenced_name IN (SELECT table_name FROM user_tables)
ORDER BY referencing_type, referencing_name;

-- Direct dependencies for a specific procedure (Replace PROC_NAME)
SELECT referenced_name, referenced_type
FROM user_dependencies
WHERE referencing_name = 'PROC_NAME';

-- Dependency tree for PL/SQL objects
SELECT referencing_name, referencing_type,
       LISTAGG(referenced_name, ', ') WITHIN GROUP (ORDER BY referenced_name) AS dependencies
FROM user_dependencies
WHERE referencing_type IN ('PACKAGE', 'PROCEDURE', 'FUNCTION')
GROUP BY referencing_name, referencing_type
ORDER BY referencing_type, referencing_name;

-- ============================================
-- EXERCISE 6: Design your own backup strategy
-- ============================================
-- Strategy Steps (using only SQL access):
-- 1. Document Structure: Query user_objects and user_tables to log object counts and row counts for post-migration verification.
-- 2. Extract Clean DDL: Use DBMS_METADATA with SESSION_TRANSFORM set to remove storage/schema attributes. Generate scripts for Tables, Indexes, Views, Sequences, Constraints, and Code.
-- 3. Reload in Strict Order: Recreate the schema on the target database in the following sequence: 
--    Tables (without constraints) -> Sequences -> Indexes -> Add Constraints (FKs) -> Views -> Procedures/Functions/Packages -> Triggers.
-- 4. Verify Transfer: Compare object counts and row counts against the documentation created in Step 1.

-- ============================================
-- DISCUSSION QUESTIONS
-- ============================================
-- Q1: What are the limitations of DBMS_METADATA vs expdp?
-- A: DBMS_METADATA only exports DDL (no data), requires manual processing, and struggles with massive schemas. 
--    Data Pump (expdp) is much faster, exports both data and DDL, and handles large schemas effortlessly, 
--    but it strictly requires DBA directory access. Use DBMS_METADATA when you only have standard SQL access.

-- Q2: If you have circular dependencies (A depends on B, B depends on A), how would you handle the reload?
-- A: Oracle generally handles standard table circular dependencies automatically if you create all tables first 
--    and apply foreign key constraints afterward. For PL/SQL objects, create the package specifications first, 
--    then compile the package bodies.

-- Q3: Your company gives you read-only access to an old database and wants you to recreate the schema on a new database. What is your plan?
-- A: 1. Document the source schema structure.
--    2. Configure DBMS_METADATA to emit clean DDL (EMIT_SCHEMA=false).
--    3. Identify dependencies and check for any remaining schema-qualified references.
--    4. Clean up the extracted DDL scripts.
--    5. Provision the new schema user on the target database.
--    6. Run the DDL scripts in dependency-safe order (Tables -> Constraints -> Indexes -> Views -> Code).
--    7. Verify successful creation using object counts.
--    8. Migrate data using INSERT statements or CSV exports if applicable.