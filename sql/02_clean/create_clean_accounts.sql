-- ========================================================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Create and Insert
-- SCHEMA: 	Clean (churn_clean)
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_clean;

-- ========================================================================================================================================================================================================
-- accounts	→	contains metadata about each customer (company) using the SaaS platform
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE churn_clean.accounts (
    account_id      VARCHAR(50)                         NOT NULL,
    account_name    VARCHAR(255)                        NOT NULL,
    industry        VARCHAR(100)                        NOT NULL,
    country         CHAR(2)                             NOT NULL CHECK (CHAR_LENGTH(country) = 2),
    signup_date     DATE                                NOT NULL,
    referral_source ENUM('organic','ads','event','partner','other'),
    plan_tier       ENUM('Basic','Pro','Enterprise')    NOT NULL,
    seats           INT                                 NOT NULL DEFAULT 1 CHECK (seats > 0),
    is_trial        BOOLEAN                             NOT NULL DEFAULT FALSE,
    churn_flag      BOOLEAN                             NOT NULL DEFAULT FALSE,

    PRIMARY KEY (account_id)
);
-- ========================================================================================================================================================================================================
-- Insert first to enforce foreign key dependency order
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO churn_clean.accounts (
    account_id,
    account_name,
    industry,
    country,
    signup_date,
    referral_source,
    plan_tier,
    seats,
    is_trial,
    churn_flag
)
SELECT
    TRIM(account_id)                                                AS account_id,
    TRIM(account_name)                                              AS account_name,
    TRIM(industry)                                                  AS industry,
    UPPER(TRIM(country))                                            AS country,
    STR_TO_DATE(NULLIF(TRIM(signup_date), ''), '%d/%m/%Y')          AS signup_date,
    NULLIF(TRIM(referral_source), '')                               AS referral_source,
    CASE LOWER(TRIM(plan_tier))														
        WHEN 'basic'      THEN 'Basic'								
        WHEN 'pro'        THEN 'Pro'								-- Sanity check → SELECT DISTINCT plan_tier validation on churn_raw.accounts + subscriptions
        WHEN 'enterprise' THEN 'Enterprise'							-- returned zero unrecognised values → ELSE NULL safe and will not violate constraint					
        ELSE NULL																	
    END                                                             AS plan_tier,
    COALESCE(CAST(NULLIF(TRIM(seats), '') AS UNSIGNED), 1)          AS seats,		-- COALESCE: defence for seat number and other numeric fields
    LOWER(TRIM(is_trial))    = 'true'                               AS is_trial,	-- to mitigate NULL constraint violation risk
    LOWER(TRIM(churn_flag))  = 'true'                               AS churn_flag
FROM churn_raw.accounts;