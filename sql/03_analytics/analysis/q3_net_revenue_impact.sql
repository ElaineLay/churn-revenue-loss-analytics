-- ================================================================================================================================================================
-- PROJECT:	Churn Revenue Loss Analytics → Analysis

-- QUERY: 	Q3 → Net Revenue Impact
-- PURPOSE:	Measures the net financial impact of churn - defined as churned MRR minus refunds issued
-- SOURCE:	fact_subscriptions, fact_churn_events, dim_account
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_analytics;

-- ================================================================================================================================================================
-- Q3: Net Revenue Impact	→ What is the real financial cost of churn after accounting for refunds? (by segment)
-- 							→ Design: CTE used to pre-aggregate fact_subscriptions and fact_churn_events to account level (one row per account) before join to 
-- 									  prevent fan-out from multiple concurrent subscriptions per account (which would inflate refund amount); 
-- 									  plan_tier segment excluded because cannot cleanly join to dim_subscription (joined via subscription_key, not account_key) 
-- 									  without reintroducing fan-out; financial impact of churn at account level; introducing initial_plan_tier segment as proxy 
-- 									  for churn-time tier is analytically misleading at this grain
-- 							→ Observations:		at industry level, Cybersecurity carries the highest total churned MRR at $279k  followed by Fintech ($253k), 
-- 												DevTools ($239k), HealthTech ($209k), and EdTech ($199k) (refer to Q3.1 below);
-- 												refunds are negigible across every industry, representing less than 1% of churned MRR in every case; 
-- 												net revenue impact closely mirrors gross churned MRR, confirming that churn losses are not being meaningfully 
-- 												offset by refund activity 
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------

WITH churned_mrr AS (		-- CTE 1 → aggregate churned MRR at account level														 
	SELECT			
		fs.account_key,
		SUM(fs.mrr) AS churned_mrr_amount
	FROM churn_analytics.fact_subscriptions AS fs
	WHERE fs.is_churned = 1						 		
	GROUP BY fs.account_key
),
refunds AS (			    -- CTE 2 → aggregate refunds at account level								
	SELECT
		ce.account_key,
		SUM(ce.refund_amount_usd) AS total_refunds
	FROM churn_analytics.fact_churn_events  AS ce
	GROUP BY ce.account_key
)
SELECT
	da.industry,
    da.country,
    SUM(cm.churned_mrr_amount)					 AS churned_mrr,
    SUM(COALESCE(r.total_refunds, 0))			 AS total_refunds,			-- Coalesce: return total refund; for churned accounts with no churn event record →
																			-- 			 treat as 0 instead of returning Null value
   ROUND(SUM(cm.churned_mrr_amount) -										
		  SUM(COALESCE(r.total_refunds, 0)), 2)	 AS net_revenue_impact,		-- total refund subtracted because it represents additional monies leaving the business
																			-- beyond lost subscription revenue 
	RANK() OVER(ORDER BY 
		SUM(cm.churned_mrr_amount) -
		SUM(COALESCE(r.total_refunds, 0)) DESC)  AS net_impact_rank

FROM churned_mrr AS cm
	LEFT JOIN refunds AS r								-- Left Join: retain all churned accounts (all cm records) even if no matching churn event exists
    ON cm.account_key = r.account_key				
    INNER JOIN churn_analytics.dim_account AS da		-- Inner Join: retain all matching records
    ON cm.account_key = da.account_key 				
    
GROUP BY da.industry, da.country

ORDER BY net_revenue_impact DESC;


-- ================================================================================================================================================================
-- Q3.1: Total Churned MRR by Industry		→ Which industry has the highest total churned MRR across all markets? (findings in Observations)
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
WITH churned_mrr AS (		-- CTE 1 → aggregate churned MRR at account level														 
	SELECT			
		fs.account_key,
		SUM(fs.mrr) AS churned_mrr_amount
	FROM churn_analytics.fact_subscriptions AS fs
	WHERE fs.is_churned = 1						 		
	GROUP BY fs.account_key
)
SELECT
	da.industry,
    SUM(cm.churned_mrr_amount)			    AS churned_mrr
FROM churned_mrr AS cm
	INNER JOIN churn_analytics.dim_account  AS da		-- Inner Join: retain all matching records
    ON cm.account_key = da.account_key 	
GROUP BY da.industry
ORDER BY churned_mrr DESC; 