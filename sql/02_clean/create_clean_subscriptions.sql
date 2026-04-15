-- ========================================================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Create and Insert
-- SCHEMA: 	Clean (churn_clean)
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_clean;

-- ========================================================================================================================================================================================================
-- subscriptions →	traces history of every subscription instance tied to an account
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE churn_clean.subscriptions (
    subscription_id    VARCHAR(50)                         NOT NULL,
    account_id         VARCHAR(50)                         NOT NULL,
    start_date         DATE                                NOT NULL,
    end_date           DATE,
    plan_tier          ENUM('Basic','Pro','Enterprise')    NOT NULL,
    seats              INT                                 NOT NULL DEFAULT 1 CHECK (seats > 0),
    mrr_amount         DECIMAL(10,2)                       NOT NULL DEFAULT 0.00 CHECK (mrr_amount >= 0),
    is_trial           BOOLEAN                             NOT NULL DEFAULT FALSE,
    upgrade_flag       BOOLEAN                             NOT NULL DEFAULT FALSE,
    downgrade_flag     BOOLEAN                             NOT NULL DEFAULT FALSE,
    churn_flag         BOOLEAN                             NOT NULL DEFAULT FALSE,
    billing_frequency  ENUM('monthly','annual')            NOT NULL,
    auto_renew_flag    BOOLEAN                             NOT NULL DEFAULT FALSE,

    PRIMARY KEY (subscription_id),

    CONSTRAINT fk_subscription_account
        FOREIGN KEY (account_id) REFERENCES churn_clean.accounts(account_id),

    CONSTRAINT check_subscription_dates
        CHECK (end_date IS NULL OR end_date >= start_date)
);

INSERT INTO churn_clean.subscriptions (
    subscription_id,
    account_id,
    start_date,
    end_date,
    plan_tier,
    seats,
    mrr_amount,
    is_trial,
    upgrade_flag,
    downgrade_flag,
    churn_flag,
    billing_frequency,
    auto_renew_flag
)
SELECT
    TRIM(subscription_id)                                               AS subscription_id,
    TRIM(account_id)                                                    AS account_id,
    STR_TO_DATE(NULLIF(TRIM(start_date), ''), '%Y-%m-%d')               AS start_date,
    STR_TO_DATE(NULLIF(TRIM(end_date),   ''), '%Y-%m-%d')               AS end_date,
    CASE LOWER(TRIM(plan_tier))
        WHEN 'basic'      THEN 'Basic'									
        WHEN 'pro'        THEN 'Pro'
        WHEN 'enterprise' THEN 'Enterprise'
        ELSE NULL														
    END                                                                 AS plan_tier,
    COALESCE(CAST(NULLIF(TRIM(seats), '') AS UNSIGNED), 1)              AS seats,
    COALESCE(CAST(NULLIF(TRIM(mrr_amount), '') AS DECIMAL(10,2)), 0.00)	AS mrr_amount,  
    LOWER(TRIM(is_trial))        = 'true'                               AS is_trial,
    LOWER(TRIM(upgrade_flag))    = 'true'                               AS upgrade_flag,
    LOWER(TRIM(downgrade_flag))  = 'true'                               AS downgrade_flag,
    LOWER(TRIM(churn_flag))      = 'true'                               AS churn_flag,
    LOWER(TRIM(billing_frequency))                                      AS billing_frequency,
    LOWER(TRIM(auto_renew_flag)) = 'true'                               AS auto_renew_flag
FROM churn_raw.subscriptions;