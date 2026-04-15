-- ================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Analysis

-- QUERY:	Q1 → Churned MRR by Segment
-- PURPOSE:	Identifies where revenue loss from churn is concentrated across industry, country, and plan_tier
-- SOURCE:	fact_subscriptions, dim_account, dim_subscription
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_analytics;

-- ================================================================================================================================================================
-- Q1: The Financial Reality	→ Where is churn driving the greatest revenue loss? (absolute impact)
-- 								→ Observations: 	Enterprise tier dominates revenue loss across all segments - 9 out of top 10 segments by churned MRR are Enterprise;
-- 										 			HealthTech/US/Enterprise is the single highest loss segment at $136k ($24k ahead of second-ranked segment)
-- 										 			US most represented country by absolute loss, but churn rate is needed to determine whether this reflects:
-- 												 		a) higher churn frequency; or
-- 												 		b) greater market exposure 
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
	da.industry,
    da.country,
    ds.plan_tier,
    SUM(fs.mrr)							   		AS churned_mrr,
    RANK() OVER(ORDER BY SUM(fs.mrr) DESC) 		AS revenue_loss_rank
    
FROM churn_analytics.fact_subscriptions   		AS fs
	INNER JOIN churn_analytics.dim_account 		AS da
    ON fs.account_key = da.account_key
    
    INNER JOIN churn_analytics.dim_subscription AS ds
    ON fs.subscription_key = ds.subscription_key

WHERE is_churned = 1

GROUP BY
	da.industry,
    da.country,
    ds.plan_tier
    
ORDER BY churned_mrr DESC;