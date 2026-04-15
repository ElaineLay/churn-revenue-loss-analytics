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
-- 2. dim_account		→ Source: 		churn_clean.accounts (alias: a)
-- 						→ Grain:  		one row per account
-- 										→ validated: expect 500 rows (one per account); confirmed against churn_clean.accounts
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO churn_analytics.dim_account (
	account_id,			 			-- account_key omitted → AUTO_INCREMENT surrogate assigned by database on insert
    account_name,
    industry,
    country,
    initial_plan_tier
)
SELECT
	a.account_id,	
    a.account_name,
    a.industry,
    a.country,
    a.plan_tier						-- snapshot: subscription plan at account entry, not at time of billing
									-- 			 descriptive attribute only (does not track changes)
FROM churn_clean.accounts AS a;