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
-- 4. dim_churn_reason		→ Source: manual ETL enrichment (reason_layer + reason_category defined in ETL layer); reason_code from churn_clean.churn_events
-- 							→ Grain:  one row per reason
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO churn_analytics.dim_churn_reason (	
	churn_reason_key, 				
    reason_code, 
    reason_label,
    reason_category
)
VALUES (
	0,						 	-- execute seed row first: churn_reason_key = 0 is a sentinel value and default FK target in fact_churn_events for future or unmapped		
    'unknown',				 	--                         reason codes; AUTO_INCREMENT does not generate 0 naturally so this row cannot be overwritten by legitimate
    'Unknown/Not Captured',  	-- 						   insert (canonical handler or mechanism for unknown reason codes)
    NULL 					    -- update: fact_churn_events.churn_reason_key explicitly set to 0 in original DDL → but AUTO_INCREMENT treated 0 as NULL and assigned
								-- key 1 instead; fact_churn_events DEFAULT updated to DEFAULT 1 accordingly via ALTER TABLE 
);
INSERT INTO churn_analytics.dim_churn_reason
	(reason_code, reason_label, reason_category)		   
VALUES
	('pricing',    'Pricing / Cost Concerns',    'Commercial'),				 -- known reason_code (churn_event) → manual insert with ETL enrichment (to map each
	('budget',     'Budget Constraints',         'Commercial'),				 -- known code to its label and category explicitly)
	('competitor', 'Moved to Competitor',        'Commercial'),				 -- 	reason_label → defined for readability
	('support',    'Poor Support Experience',    'Product & Experience'),	 -- 	reason_category → defined to reflect SaaS executive-level business ownership
	('features',   'Missing Features',           'Product & Experience');	 -- 		1. Commercial 	→ pricing, value perception, competitive positioning 
																			 -- 		   		(Sales / Revenue team ownership) 
																			 -- 		2. Product & Experience 	→ product capability, support quality 
                                                                             -- 			    (Product / Customer Success team ownership)