-- ================================================================================================================================================================
-- PROJECT:  Churn Revenue Loss Analytics → Analysis

-- QUERY:	 Q5 → Customer Engagement and Support Profile of Churned versus Retained Accounts
-- PURPOSE:	 Compares behavioural metrics between churned and retained subscriptions to surface patterns or signals that precede churn
-- SOURCE:	 fact_subscription_usage, dim_account, dim_subscription
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_analytics;

-- ================================================================================================================================================================
-- Q5: Behavioural Signals Preceding Churn → What behaviours (measures) characterise churned accounts?
-- 										   → Where is the divergence from retained accounts most pronounced?
-- 										   → Design: conditional aggregation used to compare churned versus retained subscriptions from the same population - avg
-- 													 behavioural profile per subscription collected (so results not distorted by population size);
-- 													 is_churned mirrored in fact_subscription_usage - design choice enables clean join to dim_subscription because
-- 													 same subscription-month grain (no fan-out risk)
-- 										   → Observations:	Behavioural divergence between churned and retained accounts is negligible across all segments —
--              											the largest active_days delta is -0.07 (EdTech/Enterprise); other support metrics show similarly
-- 															marginal differences; 
-- 															this suggests usage behaviour does not meaningfully predict churn - churn in this dataset is not preceded 
-- 															by observable engagement decline; likely reflects the synthetic nature of the data rather than a real 
-- 															SaaS business pattern; in a production environment, stronger behavioural signals would be expected and 
-- 															this query framework would surface them
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
	da.industry,
    ds.plan_tier,
    
    ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.active_days END), 2)		     AS avg_active_days_churned,		-- comparison profile: calculate churned and retained
    ROUND(AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.active_days END), 2)		     AS avg_active_days_retained,		-- subscriptions from same population, then compute divergence
	ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.active_days END) -													
		  AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.active_days END), 2)		     AS active_days_delta,
         
    ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.feature_adoption_count END), 2)  AS avg_feature_count_churned,
    ROUND(AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.feature_adoption_count END), 2)  AS avg_feature_count_retained,
	ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.feature_adoption_count END) -    
          AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.feature_adoption_count END), 2)  AS avg_feature_count_delta,
         
    ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.consecutive_low_engagement_months END), 2)      AS avg_low_engagement_churned,
    ROUND(AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.consecutive_low_engagement_months END), 2)      AS avg_low_engagement_retained,
    ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.consecutive_low_engagement_months END) -
          AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.consecutive_low_engagement_months END), 2)	    AS avg_low_engagement_delta, 
         
    ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.support_tickets_opened END), 2)                 AS avg_support_tickets_churned,
    ROUND(AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.support_tickets_opened END), 2)                 AS avg_support_tickets_retained,
	ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.support_tickets_opened END) -
          AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.support_tickets_opened END), 2) 				AS avg_support_tickets_delta, 
         
	ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.avg_satisfaction_score END), 2)                 AS avg_satisfaction_churned,
    ROUND(AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.avg_satisfaction_score END), 2)                 AS avg_satisfaction_retained,
    ROUND(AVG(CASE WHEN fsu.is_churned = 1 THEN fsu.avg_satisfaction_score END) -
		  AVG(CASE WHEN fsu.is_churned = 0 THEN fsu.avg_satisfaction_score END), 2) 				AS avg_satisfaction_delta
 
FROM churn_analytics.fact_subscription_usage AS fsu
	INNER JOIN churn_analytics.dim_account AS da
    ON fsu.account_key = da.account_key
    
    INNER JOIN churn_analytics.dim_subscription AS ds
    ON fsu.subscription_key = ds.subscription_key

GROUP BY 
	da.industry,
    ds.plan_tier
ORDER BY active_days_delta ASC; 	-- display so most negative deltas (where churned accounts least engaged relative to retained appear first)