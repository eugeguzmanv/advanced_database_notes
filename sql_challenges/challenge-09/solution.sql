-- ============================================================
-- EXERCISE 1 — Simple Transaction (Commit)
-- ============================================================

-- Transfer $50 from account 3 to account 1
UPDATE accounts 
SET balance = balance - 50 
WHERE account_id = 3;

UPDATE accounts 
SET balance = balance + 50 
WHERE account_id = 1;

-- Save changes permanently
COMMIT;


-- ============================================================
-- EXERCISE 2 — Transaction Rollback
-- ============================================================

-- Attempt a large transfer
UPDATE accounts 
SET balance = balance - 10000 
WHERE account_id = 2;

UPDATE accounts 
SET balance = balance + 10000 
WHERE account_id = 3;

-- View the pending state
SELECT account_id, owner_name, balance 
FROM accounts 
WHERE account_id IN (2, 3);

-- Undo the uncommitted changes
ROLLBACK;


-- ============================================================
-- EXERCISE 3 — Savepoints
-- ============================================================

-- 1. Add $25 to Alice
UPDATE accounts SET balance = balance + 25 WHERE account_id = 1;

-- 2. Set the savepoint
SAVEPOINT alice_update_done;

-- 3. Deduct $25 from Charlie (The mistake)
UPDATE accounts SET balance = balance - 25 WHERE account_id = 3;

-- 4. Rollback to the savepoint 
--    (Keeps Alice's +$25 but erases Charlie's -$25)
ROLLBACK TO SAVEPOINT alice_update_done;

-- Commit the valid portion of the transaction
COMMIT;

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;


-- ============================================================
-- EXERCISE 4 — Procedure with Transaction Control & Exceptions
-- ============================================================

CREATE OR REPLACE PROCEDURE deposit_funds (
    p_account_id IN NUMBER,
    p_amount     IN NUMBER
) AS
    -- Custom error for invalid amounts
    e_invalid_amount EXCEPTION;
BEGIN
    -- 1. Validate amount
    IF p_amount <= 0 THEN
        RAISE e_invalid_amount;
    END IF;

    -- 2. Add amount to balance
    UPDATE accounts 
    SET balance = balance + p_amount 
    WHERE account_id = p_account_id;

    -- Check if the account exists
    IF SQL%NOTFOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Account ID ' || p_account_id || ' not found.');
    END IF;

    -- 3. COMMIT on success
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Deposit successful for Account ' || p_account_id);

EXCEPTION
    -- 4. ROLLBACK + re-raise on any error
    WHEN e_invalid_amount THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Deposit amount must be greater than zero.');
        
    WHEN OTHERS THEN
        ROLLBACK;
        -- Re-raise actual system error (e.g., connection drop, constraint violation)
        RAISE;
END;
/

-- ============================================================
-- TEST — Exercise 4 Procedure
-- ============================================================

-- Valid deposit
EXEC deposit_funds(3, 75);
SELECT * FROM accounts WHERE account_id = 3;

-- Invalid deposit (Should trigger an error)
EXEC deposit_funds(3, -10);


-- ============================================================
-- EXERCISE 5 — Discussion: Transaction Management Concepts
-- ============================================================

-- Q1: The Booking System
--   * Inside the Transaction: (a) Reserve time slot, (b) Create appointment record.
--   * Outside the Transaction: (c) Send confirmation notification.
-- -> Why? Database transactions ensure Atomicity (all or nothing) for database 
--    changes. External actions (emails/APIs) cannot be rolled back. If the DB 
--    fails after sending the email, the user thinks they have an appointment. 
--    Commit the data first, then trigger external notifications.

-- Q2: The Nested Commit Problem
-- -> Why avoid COMMIT in procedures? It breaks encapsulation for the caller. 
--    A COMMIT saves everything pending in the current session. If a developer 
--    runs three updates and then calls your procedure, your COMMIT finalizes 
--    their updates prematurely, breaking their ability to ROLLBACK if needed. 
--    Procedures usually leave transaction control to the final caller.

-- Q3: Functions vs. Procedures in SELECT statements
--   * Functions: yes.
--   * Procedures: no.
-- -> Why? Functions return a value based on input. As long as a function is pure 
--    (performs no INSERT/UPDATE/DELETE), it can be used in a SELECT to calculate 
--    values per row. 
-- -> Procedures are designed for side effects (actions). Allowing a procedure 
--    inside a read-only SELECT statement would mean simply "viewing" data could 
--    change the database state, violating fundamental SQL principles.