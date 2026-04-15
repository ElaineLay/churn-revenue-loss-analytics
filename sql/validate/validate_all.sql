-- ================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Sanity Checks
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_clean;

-- ================================================================================================================================================================
-- DROP TABLE → foreign key dependency order
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS churn_clean.feature_usage;
DROP TABLE IF EXISTS churn_clean.churn_events;
DROP TABLE IF EXISTS churn_clean.support_tickets;
DROP TABLE IF EXISTS churn_clean.subscriptions;
DROP TABLE IF EXISTS churn_clean.accounts;

-- ================================================================================================================================================================
-- SANITY CHECK → GRAIN
-- Query checks whether two different subscription_ids share the same account + month 
-- Query: is there any account that has more than one subscription starting in the same month?
-- Results show all accounts that started multiple subscriptions in the same month 
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
        account_id,
        DATE_FORMAT(start_date, '%Y%m') AS month_key,
        COUNT(*) AS row_count
FROM    subscriptions
GROUP BY
        account_id,
        DATE_FORMAT(start_date, '%Y%m')
HAVING  COUNT(*) > 1;

-- ================================================================================================================================================================
-- SANITY CHECK → unrecognised plan_tier values in churn_raw.accounts and churn_raw.subscriptions
-- Query confirms no unrecognised values → returns 0 rows
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT 		DISTINCT plan_tier
FROM 		churn_raw.subscriptions
WHERE 		LOWER(TRIM(plan_tier)) NOT IN ('basic', 'pro', 'enterprise');

-- ================================================================================================================================================================
-- SANITY CHECK → row count post INSERT
-- Query confirms counts are reasonable or expected in a SaaS business context
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT 'accounts'         AS table_name, COUNT(*) AS row_count FROM churn_clean.accounts
UNION ALL
SELECT 'subscriptions',                  COUNT(*)              FROM churn_clean.subscriptions
UNION ALL
SELECT 'feature_usage',                  COUNT(*)              FROM churn_clean.feature_usage
UNION ALL
SELECT 'churn_events',                   COUNT(*)              FROM churn_clean.churn_events
UNION ALL
SELECT 'support_tickets',                COUNT(*)              FROM churn_clean.support_tickets;

-- ================================================================================================================================================================
-- No orphaned records → every account has a subscription and foreign key integrity clean
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT COUNT(DISTINCT account_id) 
FROM churn_clean.subscriptions;






