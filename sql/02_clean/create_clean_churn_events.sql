-- ========================================================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Create and Insert
-- SCHEMA: 	Clean (churn_clean)
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_clean;

-- ========================================================================================================================================================================================================
-- churn_events →	documents churn outcomes for accounts that ended their service
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE churn_clean.churn_events (
    churn_event_id           VARCHAR(50)    NOT NULL,
    account_id               VARCHAR(50)    NOT NULL,
    churn_date               DATE           NOT NULL,
    reason_code              VARCHAR(50)    NOT NULL,
    refund_amount_usd        DECIMAL(10,2)  NOT NULL DEFAULT 0.00 CHECK (refund_amount_usd >= 0),
    preceding_upgrade_flag   BOOLEAN        NOT NULL DEFAULT FALSE,
    preceding_downgrade_flag BOOLEAN        NOT NULL DEFAULT FALSE,
    is_reactivation          BOOLEAN        NOT NULL DEFAULT FALSE,
    feedback_text            TEXT,

    PRIMARY KEY (churn_event_id),

    CONSTRAINT fk_churn_account
        FOREIGN KEY (account_id) REFERENCES churn_clean.accounts(account_id)
);

INSERT INTO churn_clean.churn_events (
    churn_event_id,
    account_id,
    churn_date,
    reason_code,
    refund_amount_usd,
    preceding_upgrade_flag,
    preceding_downgrade_flag,
    is_reactivation,
    feedback_text
)
SELECT
    churn_event_id,
    account_id,
    churn_date,
    reason_code,
    refund_amount_usd,
    preceding_upgrade_flag,
    preceding_downgrade_flag,
    is_reactivation,
    feedback_text
FROM (
    SELECT
        TRIM(churn_event_id)                                                    AS churn_event_id,
        TRIM(account_id)                                                        AS account_id,
        STR_TO_DATE(NULLIF(TRIM(churn_date), ''), '%d/%m/%Y')                   AS churn_date,
        NULLIF(TRIM(reason_code), '')                                           AS reason_code,
        CAST(COALESCE(NULLIF(TRIM(refund_amount_usd), ''), 0) AS DECIMAL(10,2)) AS refund_amount_usd,
        LOWER(TRIM(preceding_upgrade_flag))   = 'true'                          AS preceding_upgrade_flag,
        LOWER(TRIM(preceding_downgrade_flag)) = 'true'                          AS preceding_downgrade_flag,
        LOWER(TRIM(is_reactivation))          = 'true'                          AS is_reactivation,
        NULLIF(TRIM(feedback_text), '')                                         AS feedback_text,
        
        ROW_NUMBER() OVER (															-- dedupe: defence against duplicate churn_event_ids in source data 												   
            PARTITION BY churn_event_id										        -- which would inflate refund_amount_usd
            ORDER BY STR_TO_DATE(NULLIF(TRIM(churn_date), ''), '%d/%m/%Y') DESC		-- resolution: retain record with most recent churn_date per churn_event_id
        ) AS row_num

    FROM churn_raw.churn_events
) AS deduplicated_churn
WHERE row_num = 1;