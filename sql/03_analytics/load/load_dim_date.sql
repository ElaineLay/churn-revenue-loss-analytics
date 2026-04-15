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
--   1. dim_date		→ Source: generated (table not in clean schema)
-- 						→ Range:  date spine dynamically derived from earliest start_date to latest end_date in subscriptions (2023-01-09, 2024-12-31)
-- 						→ Grain:  one row per calendar month
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO churn_analytics.dim_date (
	date_key,				
    month_start,							
    month_number,			
    month_name,		
    quarter,
    year,	
    is_current_month
)
WITH RECURSIVE month_spine AS (
	SELECT
		DATE_FORMAT(MIN(start_date), '%Y-%m-01') AS month_start	-- anchor member: start of date range (first day of calendar month)
    FROM churn_clean.subscriptions
    
    UNION ALL													-- connector: combine result set of both SELECT statements											    
    
    SELECT														
		DATE_ADD(month_start, INTERVAL 1 MONTH)					-- recursive member: references named CTE
	FROM month_spine 												
    WHERE DATE_ADD(month_start, INTERVAL 1 MONTH) <= (			-- recursively add one month until upper bound (terminating condition)
		SELECT 
			GREATEST (
				COALESCE(MAX(end_date), MAX(start_date)),		-- defense mechanism: if all end_dates Null, return latest start_date
                MAX(start_date)									-- extend date spine to cover latest subscription activity 
			)
		FROM churn_clean.subscriptions
	)
)
SELECT														    
	YEAR(month_start) * 100 + MONTH(month_start) 							      AS date_key,	     -- derive from canonical date column (month_start) and convert to key format: YYYYMM
    month_start,
    MONTH(month_start)															  AS month_number,   -- return month part of a date (1-12)
    MONTHNAME(month_start)						 								  AS month_name,     -- return full name of month
    QUARTER(month_start)														  AS quarter,		 -- return the quarter of the year (1-4)
    YEAR(month_start)															  AS year,			 -- return year part of a date
    CASE
		WHEN YEAR(month_start) * 100 + MONTH(month_start) =											 -- fictitious data set	→ in query time, is_current_month should flag the latest month
	         YEAR(MAX(month_start) OVER()) * 100 + MONTH(MAX(month_start) OVER())					 -- in the data; MAX window function takes the maximum month_start across entire result set;			
		THEN 1 ELSE 0																				 -- flags if row is from the latest month available in the data 
	END																			  AS is_current_month
    
FROM 	 month_spine
ORDER BY month_start;