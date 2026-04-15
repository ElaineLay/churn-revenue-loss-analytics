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
-- 6. fact_churn_events		→ Source: churn_clean.churn_events (alias: ce)
-- 							→ Grain:  one row per churn event
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO churn_analytics.fact_churn_events (
	churn_event_id,											  -- churn_event_key omitted → AUTO_INCREMENT surrogate assigned by database on INSERT
	account_key,
	churn_date_key,
    churn_reason_key,
	refund_amount_usd,
	is_reactivation,
	preceding_upgrade_flag,
	preceding_downgrade_flag
)
SELECT
	ce.churn_event_id,
    da.account_key,
    YEAR(ce.churn_date) * 100 + MONTH(ce.churn_date) AS churn_date_key,
    COALESCE(cr.churn_reason_key, 1)				 AS churn_reason_key,	-- if unmatched reason_code in dim_churn_reason returns Null → COALESCE falls back to
    ce.refund_amount_usd,													-- seed row (key: 1, 'unknown'); keeps FK valid
    ce.is_reactivation,
    ce.preceding_upgrade_flag,
    ce.preceding_downgrade_flag

FROM churn_clean.churn_events AS ce

	INNER JOIN churn_analytics.dim_account AS da			-- SK lookup: churn_events joined to dim_account on account_id → Inner Join used to silently exclude
    ON ce.account_id = da.account_id						-- events with no matching rows in ce, instead of inserting row with Null FK 
    
    LEFT JOIN churn_analytics.dim_churn_reason AS cr	    -- SK lookup: churn_events joined to dim_churn_reason on natural key: reason_code → Left Join used to
    ON ce.reason_code = cr.reason_code;						-- retain all churn events regardless of whether reason_code matches dim_churn_reason; unmatched codes
															-- handled by COALESCE