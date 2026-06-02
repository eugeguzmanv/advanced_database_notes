--------------------------------------------------------------------------------
---------------- Step 1: Create Tables (Operational Layer)
--------------------------------------------------------------------------------
CREATE TABLE tickets (
    ticket_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title       VARCHAR2(200) NOT NULL,
    status      VARCHAR2(20) NOT NULL,
    priority    VARCHAR2(15) NOT NULL,
    created_at  TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    assigned_to VARCHAR2(100) NOT NULL,
    CONSTRAINT chk_ticket_status CHECK (
        status IN ('open', 'in_progress', 'resolved', 'cancelled')
    ),
    CONSTRAINT chk_ticket_priority CHECK (
        priority IN ('low', 'medium', 'high', 'critical')
    )
);

CREATE TABLE ticket_assignments (
    assignment_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id     NUMBER NOT NULL REFERENCES tickets(ticket_id) ON DELETE CASCADE,
    assigned_to   VARCHAR2(100) NOT NULL,
    assigned_by   VARCHAR2(100),
    valid_from    TIMESTAMP NOT NULL,
    valid_to      TIMESTAMP
);


--------------------------------------------------------------------------------
------------- Step 2: Sample Data
--------------------------------------------------------------------------------


INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES ('Password reset issue', 'resolved', 'high', TIMESTAMP '2026-05-01 09:00:00', TIMESTAMP '2026-05-02 12:00:00', 'Bob Martinez');

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES ('Dashboard loading slowly', 'in_progress', 'medium', TIMESTAMP '2026-05-03 10:00:00', NULL, 'Alice Johnson');

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES ('Email notifications failing', 'resolved', 'critical', TIMESTAMP '2026-05-04 11:00:00', TIMESTAMP '2026-05-06 15:00:00', 'Carol Smith');

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES ('Mobile app crash', 'open', 'critical', TIMESTAMP '2026-05-05 13:00:00', NULL, 'David Lee');

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES ('Login authentication bug', 'resolved', 'high', TIMESTAMP '2026-05-06 09:00:00', TIMESTAMP '2026-05-08 16:00:00', 'Bob Martinez');

COMMIT;


--------------------------------------------------------------------------------
----------- Step 3: Trigger (Audit & State Management Log)
--------------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_ticket_assignment_log
AFTER INSERT OR UPDATE OF assigned_to ON tickets
FOR EACH ROW
DECLARE
    v_timestamp TIMESTAMP := SYSTIMESTAMP;
BEGIN
    IF INSERTING THEN
        INSERT INTO ticket_assignments (ticket_id, assigned_to, assigned_by, valid_from, valid_to)
        VALUES (:NEW.ticket_id, :NEW.assigned_to, NULL, :NEW.created_at, NULL);

    ELSIF UPDATING AND (:OLD.assigned_to IS NULL OR :OLD.assigned_to <> :NEW.assigned_to) THEN
        -- Terminate active historical log segment
        UPDATE ticket_assignments
           SET valid_to = v_timestamp
         WHERE ticket_id = :OLD.ticket_id
           AND valid_to IS NULL;

        -- Open fresh chronological assignment tracking entry
        INSERT INTO ticket_assignments (ticket_id, assigned_to, assigned_by, valid_from, valid_to)
        VALUES (:NEW.ticket_id, :NEW.assigned_to, :OLD.assigned_to, v_timestamp, NULL);
    END IF;
END;
/

-- Execute Trigger Integration Test Case
UPDATE tickets
SET assigned_to = 'Carol Smith'
WHERE ticket_id = 5;

COMMIT;

-- Verify chronological assignment chain
SELECT assignment_id, ticket_id, assigned_to, assigned_by, valid_from, valid_to
  FROM ticket_assignments
 WHERE ticket_id = 5
 ORDER BY valid_from ASC;


--------------------------------------------------------------------------------
---------- Step 4: Data Warehouse Tables (Dimensional Layer - Star Schema)
--------------------------------------------------------------------------------

CREATE TABLE dim_agent (
    agent_key   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agent_name  VARCHAR2(100) NOT NULL,
    team        VARCHAR2(50) NOT NULL,
    CONSTRAINT uq_agent_identity UNIQUE (agent_name, team)
);

CREATE TABLE fact_ticket_daily (
    fact_key         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key         NUMBER NOT NULL, -- Format standard: YYYYMMDD
    agent_key        NUMBER NOT NULL REFERENCES dim_agent(agent_key),
    status           VARCHAR2(20) NOT NULL,
    priority         VARCHAR2(15) NOT NULL,
    tickets_created  NUMBER DEFAULT 0 NOT NULL,
    tickets_resolved NUMBER DEFAULT 0 NOT NULL,
    CONSTRAINT chk_fact_created CHECK (tickets_created >= 0),
    CONSTRAINT chk_fact_resolved CHECK (tickets_resolved >= 0)
);


--------------------------------------------------------------------------------
------------------ Step 5: Populate dim_agent
--------------------------------------------------------------------------------

INSERT INTO dim_agent (agent_name, team) VALUES ('Alice Johnson', 'Support');
INSERT INTO dim_agent (agent_name, team) VALUES ('Bob Martinez', 'Support');
INSERT INTO dim_agent (agent_name, team) VALUES ('Carol Smith', 'Escalations');
INSERT INTO dim_agent (agent_name, team) VALUES ('David Lee', 'Escalations');

COMMIT;


--------------------------------------------------------------------------------
-------------- Step 6: Analytical Verification
--------------------------------------------------------------------------------


SELECT d.agent_name,
       d.team,
       f.date_key,
       f.status,
       f.priority,
       f.tickets_created,
       f.