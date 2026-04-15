-- ================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Analysis

-- QUERY:	 Q2 → Revenue Churn Rate by Segment
-- PURPOSE:  Measures the proportion of MRR lost to churn within each segment
-- SOURCE:   fact_subscriptions, dim_account, dim_subscription
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_analytics;

-- ================================================================================================================================================================
-- Q2: Revenue Churn Rate	→ Which segments have the highest proportional revenue churn risk? (proportional impact)
-- 							→ Design: conditional aggregation used to calculate churned and total MRR from the same population, instead of filtering rows out; Nullif
-- 									  guards against division by zero 
-- 							→ Observations:		proportional churn rate diverges significantly from absolute revenue loss (Q1) - EdTech/DE/Enterprise has 52%  
-- 												churn rate but contributes approx. $5k MRR, whereas HealthTech/US/Enterprise segment with greatest absolute loss 
-- 												($136k) ranks 26th with 14% churn rate;

-- 												strong retention: 21 segments record 0% churn rate (notable for retention prioritisation efforts)
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
	da.industry,
    da.country,
    ds.plan_tier,
    SUM(CASE WHEN fs.is_churned = 1 THEN fs.mrr ELSE 0 END) 	AS churned_mrr,			-- numerator: only add rows where mrr is churned, otherwise add 0
    SUM(fs.mrr)													AS total_mrr,			-- denominator: total mrr across all rows
    ROUND(SUM(CASE WHEN fs.is_churned = 1 
				   THEN fs.mrr ELSE 0 END) /
		  NULLIF(SUM(fs.mrr), 0) * 100, 2)						AS churn_rate,			-- ratio as percentage, rounded to two decimal places
	RANK() OVER(ORDER BY SUM(CASE WHEN fs.is_churned = 1
								  THEN fs.mrr ELSE 0 END) /								-- Rank() from highest proportional churn rate to lowest
						 NULLIF(SUM(fs.mrr), 0) DESC)			AS churn_rate_rank		-- Nullif: returns Null if total_mrr = 0, preventing division by zero
																						
FROM churn_analytics.fact_subscriptions   		 AS fs
	INNER JOIN churn_analytics.dim_account 		 AS da
    ON fs.account_key = da.account_key
    
    INNER JOIN churn_analytics.dim_subscription  AS ds
    ON fs.subscription_key = ds.subscription_key

GROUP BY
	da.industry,
    da.country,
    ds.plan_tier
    
ORDER BY churn_rate_rank;