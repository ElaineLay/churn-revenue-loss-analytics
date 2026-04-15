-- ========================================================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Create and Insert
-- SCHEMA: 	Clean (churn_clean)
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_clean;

-- ========================================================================================================================================================================================================
-- feature_usage →	captures product interaction events per subscription
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE churn_clean.feature_usage (
    usage_id             VARCHAR(50)  NOT NULL,
    subscription_id      VARCHAR(50)  NOT NULL,
    usage_date           DATE         NOT NULL,
    feature_name         VARCHAR(50)  NOT NULL,
    usage_count          INT          NOT NULL CHECK (usage_count >= 0),
    usage_duration_secs  INT          NOT NULL CHECK (usage_duration_secs >= 0),
    error_count          INT          NOT NULL DEFAULT 0 CHECK (error_count >= 0),
    is_beta_feature      BOOLEAN      NOT NULL DEFAULT FALSE,

    PRIMARY KEY (usage_id),

    CONSTRAINT fk_usage_subscription
        FOREIGN KEY (subscription_id) REFERENCES churn_clean.subscriptions(subscription_id)
);

INSERT INTO churn_clean.feature_usage (
    usage_id,
    subscription_id,
    usage_date,
    feature_name,
    usage_count,
    usage_duration_secs,
    error_count,
    is_beta_feature
)
SELECT
    usage_id,
    subscription_id,
    usage_date,
    feature_name,
    usage_count,
    usage_duration_secs,
    error_count,
    is_beta_feature
FROM (
    SELECT
        TRIM(usage_id)                                                       AS usage_id,
        TRIM(subscription_id)                                                AS subscription_id,
        STR_TO_DATE(NULLIF(TRIM(usage_date), ''), '%Y-%m-%d')                AS usage_date,
        TRIM(feature_name)                                                   AS feature_name,
        CAST(COALESCE(NULLIF(TRIM(usage_count),         ''), 0) AS UNSIGNED) AS usage_count,
        CAST(COALESCE(NULLIF(TRIM(usage_duration_secs), ''), 0) AS UNSIGNED) AS usage_duration_secs,
        CAST(COALESCE(NULLIF(TRIM(error_count),         ''), 0) AS UNSIGNED) AS error_count,
        LOWER(TRIM(is_beta_feature)) = 'true'                                AS is_beta_feature,
        
		ROW_NUMBER() OVER (					-- dedupe: raw data contains duplicate usage_ids (source data quality issue)
            PARTITION BY usage_id			-- resolution: retain record with the most recent usage_date per usage_id on assumption
            ORDER BY usage_date DESC		-- that later records represent corrections to earlier erroneous entries
        ) AS row_num
        
    FROM churn_raw.feature_usage
) AS deduplicated_usage
WHERE row_num = 1;