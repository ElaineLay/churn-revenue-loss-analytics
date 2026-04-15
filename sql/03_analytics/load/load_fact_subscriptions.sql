-- ================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Load
-- SCHEMA:  Star Schema (churn_analytics)
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_analytics;

-- ================================================================================================================================================================
-- Load: in order of FK dependency
-- 	 1. dim_date					→ no dependencies
-- 	 2. dim_account				    → no dependencies
--   3. dim_subscription			→ no dependencies
-- 	 4. dim_churn_reason			→ no dependencies; insert seed row before any fact loads
--   5. fact_subscriptions			→ depends on dim_subscription, dim_account, dim_date
-- 	 6. fact_churn_events			→ depends on dim_account, dim_date, dim_churn_reason
-- 	 7. fact_subscription_usage		→ depends on dim_subscription, dim_account, dim_date
-- 		  note: load after fact_subscriptions → is_churned sourced from subscriptions.churn_flag; no FK constraint, but logical dependency exists at ETL time


-- ================================================================================================================================================================
-- 5. fact_subscriptions		→ Source: churn_clean.subscriptions (alias: s)
-- 								→ Grain:  one row per subscription instance
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO churn_analytics.fact_subscriptions (
	subscription_key,										-- subscription_key is PK and serves as FK to dim_subscription → rationale: valid because grain is 
    account_key,											-- one row per subscription; revisit if grain expands 
    start_date_key,
    end_date_key,
	mrr,
    is_churned,
    is_upgraded,
    is_downgraded,
    auto_renew_flag
)
SELECT
	ds.subscription_key,
    da.account_key,
    YEAR(s.start_date) * 100 + MONTH(s.start_date) 		AS start_date_key,
    CASE
		WHEN s.end_date is NULL THEN NULL
        ELSE YEAR(s.end_date) * 100 + MONTH(s.end_date)
        END												AS end_date_key,
    s.mrr_amount										AS mrr,
    s.churn_flag										AS is_churned, 
    s.upgrade_flag										AS is_upgraded,
    s.downgrade_flag									AS is_downgraded,
    s.auto_renew_flag							   		AS auto_renew_flag

FROM churn_clean.subscriptions	AS s
	
    INNER JOIN churn_analytics.dim_account AS da			-- SK lookup: subscriptions joined to dim_account on account_id → Inner Join used to silently exclude subs with 
    ON s.account_id = da.account_id 						-- no matching rows in da, instead of inserting row with Null FK 
    
    INNER JOIN churn_analytics.dim_subscription AS ds		-- SK lookup: subscriptions joined to dim_subscription on subscription_id → Inner Join used to silently exclude 
    ON s.subscription_id = ds.subscription_id;				-- subs with no matching rows in ds, instead of inserting row with Null FK