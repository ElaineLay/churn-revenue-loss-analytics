-- ========================================================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Create and Insert
-- SCHEMA: 	Clean (churn_clean)
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_clean;

-- ========================================================================================================================================================================================================
-- support_tickets →	documents customer support interactions at the account level
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE churn_clean.support_tickets (
    ticket_id                    VARCHAR(50)                          NOT NULL,
    account_id                   VARCHAR(50)                          NOT NULL,
    submitted_at                 DATETIME                             NOT NULL,
    closed_at                    DATETIME                             DEFAULT NULL,
    priority                     ENUM('low','medium','high','urgent') NOT NULL,  
    first_response_time_minutes  INT                                  NOT NULL CHECK (first_response_time_minutes >= 0),
    satisfaction_score           INT                                  CHECK (satisfaction_score BETWEEN 1 AND 5),
    escalation_flag              BOOLEAN                              NOT NULL DEFAULT FALSE,

    PRIMARY KEY (ticket_id),

    CONSTRAINT fk_ticket_account
        FOREIGN KEY (account_id) REFERENCES churn_clean.accounts(account_id),

    CONSTRAINT check_ticket_dates
        CHECK (closed_at IS NULL OR closed_at >= submitted_at)
);

INSERT INTO churn_clean.support_tickets (
    ticket_id,
    account_id,
    submitted_at,	
    closed_at,
    priority,
    first_response_time_minutes,
    satisfaction_score,
    escalation_flag
)
SELECT
    TRIM(ticket_id)                                                                 AS ticket_id,
    TRIM(account_id)                                                                AS account_id,
    STR_TO_DATE(NULLIF(TRIM(submitted_at), ''), '%Y-%m-%d')                       	AS submitted_at, 		       -- source submitted_at does not have time component 
    STR_TO_DATE(NULLIF(TRIM(closed_at),    ''), '%Y-%m-%d %H:%i:%s')                AS closed_at,	
    CASE LOWER(TRIM(priority))																				
        WHEN 'low'    THEN 'low'
        WHEN 'medium' THEN 'medium'
        WHEN 'high'   THEN 'high'
        WHEN 'urgent' THEN 'urgent'
        ELSE 'low'
    END                                                                             AS priority,
    COALESCE(CAST(NULLIF(TRIM(first_response_time_minutes), '') AS UNSIGNED), 0)    AS first_response_time_minutes,
    CAST(CAST(NULLIF(TRIM(satisfaction_score), '') AS DECIMAL(3,1)) AS UNSIGNED) 	AS satisfaction_score,         -- raw values → float → CAST to decimal → CAST to int
    LOWER(TRIM(escalation_flag)) = 'true'                                           AS escalation_flag
FROM churn_raw.support_tickets;