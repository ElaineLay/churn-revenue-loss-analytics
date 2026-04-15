-- ================================================================================================================================================================
-- PROJECT: Churn Revenue Loss Analytics → Dimensional Model v2.0
-- SCHEMA: 	Star Schema (churn_analytics)

-- CHANGE LOG v2.0:
-- 			1. fact_subscription_revenue (v1.0) decomposed into two separate fact tables → rationale: source data contains two distinct business processes at
-- 					different natural grains; v1.0 incorrectly forced both grains into a single fact via an account + month composite join key (account_key, date_key)
--                  because assumed that one active subscription per account per month; this conflicts with source business model (confirmed: accounts can hold multiple,
-- 					concurrent active subscriptions)
--                  	→ corrected model separates them:
-- 							 fact_subscriptions → one row per subscription (financial snapshot)
-- 							 fact_churn_events  → one row per churn event (account-level, no subscription_id in source)
-- 								→ the two facts are bridged at query time through dim_account, not joined at ETL time 

-- 			2. dim_churn_reason added → rationale: reason_code raw VARCHAR in fact_churn_event; promoting it to a normalised dimension avoids BI tools grouping on 
-- 					inconsistent free-text values; enables rolling granular reasons into reason_category for exec-level retention segmentation

-- 			3. start_date, end_date, auto_renew_flag moved from dim_subscription to fact_subscriptions → rationale: these are facts about subscription tenure, 
-- 					not static descriptors; measures live in fact_subscriptions where they can be filtered directly (concurrent subscriptions per account)

-- 			4. fact_subscription_usage unchanged
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
USE churn_analytics;

-- ================================================================================================================================================================
-- Dimension: dim_date	→ generated month spine for time-based analysis
-- Grain:	  one row per calendar month
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE dim_date (
	date_key				INT				NOT NULL,				-- surrogate key representing month (format: YYYYMM)
    month_start				DATE			NOT NULL,				-- first day of calendar month			
    month_number			TINYINT			NOT NULL,				-- calendar month number (1-12)
    month_name				VARCHAR(10)		NOT NULL,				-- calendar month (e.g. January)
    quarter					TINYINT			NOT NULL,				-- calendar quarter (1-4)
    year				    SMALLINT		NOT NULL,				-- calendar year (e.g. 2024)
    is_current_month		BOOLEAN			NOT NULL DEFAULT 0,		-- dashboard filter flag for latest reporting month
    
    CONSTRAINT pk_dim_date	PRIMARY KEY (date_key)
);


-- ================================================================================================================================================================
-- Dimension: dim_account	→ customer account attributes for segmenting churn and revenue loss
-- Grain:	  one row per account
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE dim_account (
	account_key				INT									NOT NULL AUTO_INCREMENT,	-- surrogate key used as FK in fact tables
    account_id				VARCHAR(50)							NOT NULL,					-- natural key from source (accounts.account_id)
    account_name			VARCHAR(100)						NOT NULL,					-- company name
    industry				VARCHAR(100)						NULL, 						-- company industry
    country					CHAR(2)								NULL,						-- country code ISO
    initial_plan_tier		ENUM('Basic', 'Pro', 'Enterprise')	NULL,						-- plan tier at account entry 	→ use for entry cohort segmentation
    
    CONSTRAINT pk_dim_account	  PRIMARY KEY (account_key),
    CONSTRAINT uq_dim_account_id  UNIQUE 	  (account_id)									-- rule → each source account appears exactly once
);


-- ================================================================================================================================================================
-- Dimension: dim_subscription	→ descriptive subscription attributes for slicing revenue metrics
-- Grain:	  one row per subscription instance

-- Design:	  start_date, end_date, auto_renew_flag intentionally excluded → these are facts about subscription tenure, not static descriptors;
-- 	          measures live in fact_subscriptions where they can be filtered directly (concurrent subscriptions per account)
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE dim_subscription (
	subscription_key		 INT 								NOT NULL AUTO_INCREMENT,	-- surrogate key used as FK in fact tables
    subscription_id			 VARCHAR(50)						NOT NULL,					-- natural key from source (subscriptions.subscription_id)
    plan_tier		 		 ENUM('Basic', 'Pro', 'Enterprise') NULL,						-- service tier	→ primary dimension for revenue segmentation
	seats		 			 INT								NULL,						-- licensed user count on subscription
	is_trial	 			 BOOLEAN							NOT NULL DEFAULT 0,			-- trial flag → to exclude or isolate trial subscriptions from revenue analysis 
																							-- trial filtering through dim_subscription only → canonical source for trial classification
    billing_frequency		 ENUM('monthly', 'annual')			NULL,						-- billing interval → proxy for commitment level
    
    CONSTRAINT pk_dim_subscription		PRIMARY KEY (subscription_key),
    CONSTRAINT uq_dim_subscription_id	UNIQUE		(subscription_id)						-- rule → each source subscription appears exactly once																							
);


-- ================================================================================================================================================================
-- Dimension: dim_churn_reason	→ normalised source value for slicing churn by reason
-- Grain:	  one row per reason

-- Design:	  reason_code in dim more robust option than storing raw string in fact_churn_events → avoids BI tools grouping by free text (potential inconsistency)
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE dim_churn_reason (
	churn_reason_key		INT				NOT NULL AUTO_INCREMENT,	-- surrogate key used as FK in fact table (fact_churn_events)
    reason_code				VARCHAR(50)		NOT NULL,					-- source value	→ load note: seed row for unmapped or future codes (churn_reason_key = 0, 
																		-- 				  reason_code = 'unknown') must be inserted before fact_churn_events is loaded
                                                                        -- 				  (default FK for unmapped reason codes keeps the FK non-nullable)
    reason_label			VARCHAR(100)	NOT NULL,					-- reason as human-readable label
    reason_category			VARCHAR(50)		NULL,						-- reportable categories (e.g. 'Pricing', 'Product')
    
    CONSTRAINT pk_dim_churn_reason		PRIMARY KEY (churn_reason_key),
    CONSTRAINT uq_churn_reason_code		UNIQUE 		(reason_code)
);


-- ================================================================================================================================================================
-- Fact:	fact_subscriptions	→ one financial record per subscription
-- Grain:	one row per subscription

-- Design:  PK decision → subscription_key serves as both PK and FK to dim_subscription (1:1); valid because grain is one row per subscription and constraint
-- 			guarantees only one fact row exists per subscription; revisit if grain expands or Slowly Changing Dimension Type 2 is introduced on dim_subscription
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE fact_subscriptions (

	subscription_key		 INT			NOT NULL,				-- FK ← dim_subscription.subscription_key (also natural grain key)
    account_key				 INT			NOT NULL,				-- FK ← dim_account.account_key
    start_date_key			 INT			NOT NULL,				-- FK ← dim_date.date_key (format: YYYYMM of sub start)
    end_date_key			 INT			NULL,					-- FK ← dim_date.date_key (format: YYYYMM of sub end → Null = still active)
    
	mrr                      DECIMAL(12, 2) NOT NULL DEFAULT 0,		-- subscriptions.mrr_amount	→ monthly recurring revenue (arr derivable at query time)
    
    is_churned               TINYINT(1)     NOT NULL DEFAULT 0,		-- subscriptions.churn_flag
    is_upgraded              TINYINT(1)     NOT NULL DEFAULT 0,		-- subscriptions.upgrade_flag	→ sub had plan upgrade
    is_downgraded            TINYINT(1)     NOT NULL DEFAULT 0,		-- subscriptions.downgrade_flag	 → sub had plan downgrade
    auto_renew_flag          TINYINT(1)     NOT NULL DEFAULT 0,		-- subscriptions.auto_renew_flag	→ non-renew churn subs signal latent revenue risk
    
    CONSTRAINT pk_fact_subscriptions		PRIMARY KEY (subscription_key),
    
    CONSTRAINT fk_sub_subscription
		FOREIGN KEY (subscription_key) 		REFERENCES dim_subscription(subscription_key),
	
    CONSTRAINT fk_sub_account
		FOREIGN KEY (account_key)			REFERENCES dim_account(account_key),
	
    CONSTRAINT fk_sub_start_date
		FOREIGN KEY (start_date_key)		REFERENCES dim_date(date_key),
	
     CONSTRAINT fk_sub_end_date
		FOREIGN KEY (end_date_key)		    REFERENCES dim_date(date_key)
);

-- ================================================================================================================================================================
-- Fact:	fact_churn_events	→ one record per customer churn event
-- Grain:	one row per churn event

-- Design:  measures answer how many customers churned, when, why, and what was refunded → as noted: no direct FK between fact_churn_events and fact_subscriptions;
--          join to fact_subscriptions intentionally deferred to query time through dim_account (account_key)
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE fact_churn_events (
	
    churn_event_key				INT				NOT NULL AUTO_INCREMENT,	-- surrogate key
	churn_event_id				VARCHAR(50)		NOT NULL,					-- natural key from source (churn_events.churn_event_id)
	account_key					INT				NOT NULL,					-- FK ← dim_account.account_key
	churn_date_key				INT				NOT NULL,					-- FK ← dim_date.date_key (format: YYYYMM of churn_date)
    churn_reason_key			INT				NOT NULL DEFAULT 1,			-- FK ← dim_churn_reason (updated from DEFAULT 0 → DEFAULT 1)
																			--      rationale: DEFAULT 1 → sentinel seed row to handle unknown or unmapped reason codes;
                                                                            --                 AUTO_INCREMENT treated explicit key 0 as Null on Load
                                                                            --                 seed row assigned key 1 instead; default updated accordingly via ALTER TABLE
	refund_amount_usd			DECIMAL(12, 2)	NOT NULL DEFAULT 0,			-- churn_events.refund_amount_usd 	→ direct cost of churn event
	is_reactivation				TINYINT(1)		NOT NULL DEFAULT 0,			-- churn_events.is_reactivation		→ re-churned previously reactivated account
	preceding_upgrade_flag		TINYINT(1)		NOT NULL DEFAULT 0,			-- churn_events.preceding_upgrade_flag	 → churn followed an expansion (signals failed upsell)
	preceding_downgrade_flag	TINYINT(1)		NOT NULL DEFAULT 0,			-- churn_events.preceding_downgrade_flag  → churn followed a contraction (revenue loss pattern)
    
    CONSTRAINT pk_fact_churn_events		PRIMARY KEY (churn_event_key),
	
    CONSTRAINT uq_fact_churn_event_id 	UNIQUE (churn_event_id),	-- rule → each source churn event appears exactly once
 
	CONSTRAINT fk_churn_account
		FOREIGN KEY (account_key)	 	REFERENCES dim_account(account_key),
 
	CONSTRAINT fk_churn_date
		FOREIGN KEY (churn_date_key)	REFERENCES dim_date(date_key),
	
    CONSTRAINT fk_churn_reason
		FOREIGN KEY (churn_reason_key)  REFERENCES dim_churn_reason(churn_reason_key)
);

-- ================================================================================================================================================================
-- Fact:	fact_subscription_usage		→ behavioural engagement record per subscription per month 
-- Grain:	one row per subscription per month

-- Design: 	derived from feature_usage, support_tickets, subscriptions → note: is_churned (subscriptions.churn_flag) is mirrored in this fact to enable standalone
--          subscription usage analysis without joining back to fact_subscriptions
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE fact_subscription_usage (

	date_key                		  INT             NOT NULL,		-- FK ← derived from feature_usage.usage_date (format: YYYYMM)
    account_key						  INT			  NOT NULL,		-- FK ← dim_account.account_key (bridged via subscriptions.account_id)
    subscription_key				  INT			  NOT NULL,		-- FK ← dim_subscription.subscription_key
    
    active_days              		  SMALLINT        NULL,			-- feature_usage.usage_date		→ count distinct usage dates per subscription/month	
    feature_adoption_count            SMALLINT        NULL,			-- feature_usage.feature_name	→ count distinct features used per subscription/month	
    total_usage_count                 INT             NULL,			-- feature_usage.usage_count	→ sum of activity
    total_usage_duration_secs         INT             NULL,			-- feature_usage.usage_duration_secs	→ sum of activity session 
    avg_usage_duration_secs           DECIMAL(10, 2)  NULL,			-- feature_usage.usage_duration_secs	→ avg engagement per session
    total_error_count                 INT             NULL,			-- feature_usage.error_count	→ sum of errors to signal friction
    beta_feature_usage_count          INT             NULL,			-- feature_usage.is_beta_feature	→ count of beta feature interactions
    
    error_rate                        DECIMAL(8, 4)   NULL,			-- derived: (total_error_count / total_usage_count)
    mom_active_days_delta             SMALLINT        NULL,			-- derived: MoM delta	→ LAG(active_days, 1) OVER(PARTITION BY subscription_key ORDER BY date_key
    consecutive_low_engagement_months SMALLINT        NULL,			-- derived: window count of months below engagement threshold	→ early churn signal 
    
    support_tickets_opened            SMALLINT        NULL,			-- support_tickets	→ count support_tickets submitted in month (joined via account_id)
    support_tickets_unresolved_eom    SMALLINT        NULL, 		-- support_tickets	→ count where closed_at is Null or after end of month 
    avg_resolution_hours              DECIMAL(8, 2)   NULL, 		-- support_tickets	→ avg(closed_at - submitted_at) 
    avg_satisfaction_score            DECIMAL(4, 2)   NULL, 		-- customer satisfaction score 	→ avg satisfaction score for month
    
    is_churned						  TINYINT(1)      NOT NULL DEFAULT 0,	 				 -- subscriptions.churn_flag → mirrored from fact_subscriptions for standalone sub usage analysis 
	
    CONSTRAINT pk_fact_sub_usage	  PRIMARY KEY (date_key, account_key, subscription_key), -- grain: one subscription per month
    
	CONSTRAINT fk_usage_date
		FOREIGN KEY (date_key)		  REFERENCES dim_date(date_key),
        
	CONSTRAINT fk_usage_account
		FOREIGN KEY (account_key)	  REFERENCES dim_account(account_key),

	CONSTRAINT fk_usage_sub
		FOREIGN KEY (subscription_key)REFERENCES dim_subscription(subscription_key)
);