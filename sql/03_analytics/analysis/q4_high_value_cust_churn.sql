-- ================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Analysis

-- QUERY:	 Q4 → High Value Customer Churn by Segment
-- PURPOSE:  Identifies churn rate within the top MRR quartile to surface which segments are losing their most valuable customers disproportionately
-- SOURCE:	 fact_subscriptions, dim_account
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_analytics;

-- ================================================================================================================================================================
-- Q4: High Value Customer Churn 	→ Where should we focus retention resources for maximum ROI?
-- 									→ Design: high value threshold defined as top quartile by total account MRR (Ntile = 1);
-- 											  overall_churn_rate field included as benchmark for segment_churn_rate comparison;
-- 											  to avoid fan-out through join to dim_subscription (for accounts with multiple subscriptions), initial_plan_tier used 
-- 											  as segmentation proxy - acceptable at this grain since the analytical intent is account cohort characterisation (not
-- 											  churn-time tier attribution)
-- 									→ Observations:		HealthTech/Enterprise segment is highest risk at 22.67% (2x overall churn rate);
-- 														EdTech/Enterprise has highest churned MRR in top cohort ($89k) despite ranking third by rate - raises a 
-- 														dual priority by volume and proportional risk;
-- 														seven of fifteen high value segments churn above overall rate of 11.43% - all Enterprise or Pro initial 
-- 														plan tier - high value accounts with Basic initial tier are consistently below overall rate and appear stable
-- 													
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
WITH account_value AS (
	SELECT
		fs.account_key,
        SUM(CASE WHEN fs.is_churned = 1 THEN fs.mrr ELSE 0 END) AS churned_mrr,
        SUM(fs.mrr)												AS total_mrr
	FROM churn_analytics.fact_subscriptions AS fs
    GROUP BY fs.account_key
),

account_cohort AS (
	SELECT
		av.account_key,
        av.total_mrr,
        NTILE(4) OVER (ORDER BY av.total_mrr DESC) AS account_quartile
	FROM account_value AS av
)

SELECT
	da.industry,
    da.initial_plan_tier,
    SUM(av.churned_mrr) 						     		 AS churned_mrr,
    SUM(av.total_mrr)							     		 AS total_mrr,
    ROUND(SUM(av.churned_mrr) /
		  NULLIF(SUM(av.total_mrr), 0) * 100, 2)     		 AS segment_churn_rate,		-- churn rate within high value cohort per segment;
																						-- compare against overall_churn_rate benchmark
	ROUND(SUM(SUM(av.churned_mrr)) OVER() /
		  NULLIF(SUM(SUM(av.total_mrr)) OVER(), 0) * 100, 2) AS overall_churn_rate		-- benchmark: overall churn rate across all high value accounts (constant)

FROM account_cohort AS cohort
	INNER JOIN account_value AS av
    ON cohort.account_key = av.account_key
    
    INNER JOIN churn_analytics.dim_account AS da
    ON cohort.account_key = da.account_key

WHERE cohort.account_quartile = 1	      											   -- filter by top quartile 

GROUP BY 
	da.industry,
    da.initial_plan_tier

ORDER BY segment_churn_rate DESC;