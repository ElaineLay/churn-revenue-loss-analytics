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
-- 3. dim_subscription		→ Source:		churn_clean.subscriptions (alias: s)
-- 							→ Grain:		one row per subscription instance 
-- 											→ validated: expect 5000 rows (one per subscription); confirmed against churn_clean.subscriptions
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO churn_analytics.dim_subscription (
    subscription_id,						-- subscription_key omitted → AUTO_INCREMENT surrogate assigned by database on insert
											-- account_id omitted → account-subscription relationship resolved through fact tables, not the dimension 
    plan_tier,
	seats,
	is_trial,
    billing_frequency
)
SELECT
	s.subscription_id,			
    s.plan_tier,
	s.seats,
	s.is_trial,
    s.billing_frequency
    
FROM churn_clean.subscriptions AS s;