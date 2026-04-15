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
-- 7. fact_subscription_usage		→ Source: churn_clean.feature_usage (alias: fu) + churn_clean.support_tickets (alias: st)
-- 									→ Grain:  one row per subscription per month
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO churn_analytics.fact_subscription_usage (
    date_key,
    account_key,
    subscription_key,
    active_days,
    feature_adoption_count,
    total_usage_count,
    total_usage_duration_secs,
    avg_usage_duration_secs,
    total_error_count,
    beta_feature_usage_count,
    error_rate,
    mom_active_days_delta,
    consecutive_low_engagement_months,
    support_tickets_opened,
    support_tickets_unresolved_eom,
    avg_resolution_hours,
    avg_satisfaction_score,
    is_churned
)

WITH monthly_feature AS (
    SELECT
        fu.subscription_id,
        YEAR(fu.usage_date) * 100 + MONTH(fu.usage_date)        AS date_key,
        COUNT(DISTINCT fu.usage_date)                           AS active_days,
        COUNT(DISTINCT fu.feature_name)                         AS feature_adoption_count,
        SUM(fu.usage_count)                                     AS total_usage_count,
        SUM(fu.usage_duration_secs)                             AS total_usage_duration_secs,
        AVG(fu.usage_duration_secs)                             AS avg_usage_duration_secs,
        SUM(fu.error_count)                                     AS total_error_count,
        SUM(CASE WHEN fu.is_beta_feature = TRUE THEN 1
            ELSE 0 END)                                         AS beta_feature_usage_count
            
    FROM churn_clean.feature_usage AS fu
    GROUP BY
        fu.subscription_id,
        YEAR(fu.usage_date) * 100 + MONTH(fu.usage_date)
),
ticket_monthly AS (
    SELECT
        st.account_id,
        YEAR(st.submitted_at) * 100 + MONTH(st.submitted_at)   AS date_key,
        COUNT(*)                                               AS support_tickets_opened,
        SUM(CASE
                WHEN st.closed_at IS NULL
                OR   st.closed_at > LAST_DAY(STR_TO_DATE(
                    CONCAT(YEAR(st.submitted_at), '-', MONTH(st.submitted_at), '-01'), '%Y-%c-%d'))
                THEN 1 ELSE 0
            END)                                               AS support_tickets_unresolved_eom,
        AVG(CASE
                WHEN st.closed_at IS NOT NULL
                THEN TIMESTAMPDIFF(HOUR, st.submitted_at, st.closed_at)
            END)                                               AS avg_resolution_hours,
        AVG(st.satisfaction_score)                             AS avg_satisfaction_score
        
    FROM churn_clean.support_tickets AS st
    GROUP BY
        st.account_id,
        YEAR(st.submitted_at) * 100 + MONTH(st.submitted_at)
),
combined AS (
    SELECT
        fm.date_key,
        da.account_key,
        ds.subscription_key,
        fm.active_days,
        fm.feature_adoption_count,
        fm.total_usage_count,
        fm.total_usage_duration_secs,
        fm.avg_usage_duration_secs,
        fm.total_error_count,
        fm.beta_feature_usage_count,
        CASE
            WHEN fm.total_usage_count > 0
            THEN fm.total_error_count / fm.total_usage_count
            ELSE NULL
        END                                                     AS error_rate,
        tm.support_tickets_opened,
        tm.support_tickets_unresolved_eom,
        tm.avg_resolution_hours,
        tm.avg_satisfaction_score,
        s.churn_flag                                            AS is_churned
        
    FROM monthly_feature AS fm
        INNER JOIN churn_clean.subscriptions AS s
            ON fm.subscription_id = s.subscription_id
        INNER JOIN churn_analytics.dim_subscription AS ds
            ON fm.subscription_id = ds.subscription_id
        INNER JOIN churn_analytics.dim_account AS da
            ON s.account_id = da.account_id
        LEFT JOIN ticket_monthly AS tm
            ON s.account_id = tm.account_id
            AND fm.date_key = tm.date_key
)
SELECT
    date_key,
    account_key,
    subscription_key,
    active_days,
    feature_adoption_count,
    total_usage_count,
    total_usage_duration_secs,
    avg_usage_duration_secs,
    total_error_count,
    beta_feature_usage_count,
    error_rate,
    active_days - LAG(active_days, 1) OVER (
        PARTITION BY subscription_key
        ORDER BY date_key
    )                                                           AS mom_active_days_delta,
    SUM(CASE WHEN active_days < 5 THEN 1 ELSE 0 END) OVER (
        PARTITION BY subscription_key
        ORDER BY date_key
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                           AS consecutive_low_engagement_months,
    support_tickets_opened,
    support_tickets_unresolved_eom,
    avg_resolution_hours,
    avg_satisfaction_score,
    is_churned
    
FROM combined;
