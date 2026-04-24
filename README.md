# Churn Revenue Loss Analytics

An end-to-end SQL analytics project quantifying the revenue impact of customer churn across industry, geography, and subscription tier. 
This project was built to answer one executive question: **where is churn driving the greatest revenue loss, and which segments should be prioritised for retention?**


## Context

Customer churn is the rate at which subscribers cancel or move to a lower tier and is a significant driver of revenue loss in subscription-based software businesses. This project quantifies the financial impact of churn and examines which customer segments across industry, geography, and subscription tier pose the greatest churn risk. The aim is to determine where retention efforts should be focused to minimise loss.

## Tools

- SQL (MySQL)
- Tableau Public 


## Data

The executive question steered a targeted analysis of a multi-table synthetic relational dataset reflecting the subscription, usage support, and churn activity of a real-world SaaS business. This fictional platform simulates a B2B SaaS venture that captured customer data across a twenty-four month window, enabling a consistent analysis of churn trends over time. To uncover insights on the financial impact of churn and which segments are most at risk, this project simulates an analytics pipeline using SQL and BI tools.


## Architecture

A three-tier architecture systematically transformed raw text files into a structured model used for reporting and segmentation. Raw data was loaded into its own schema to create an auditable baseline and source of truth. This separation made it easier to distinguish genuine data quality issues from deliberate edge cases in the source data.

A separate clean layer cast types correctly, standardised categories, enforced referential integrity, and handled null values to ensure the data was consistent and usable. No business rules were imposed at this stage. Interpretive decisions about how columns should be used to answer the executive question were reserved for the analytics tier. Cleaning transformations were iterative; each column was validated against the raw data while the intentional features of the source model were preserved.  

The analytics tier implemented dimensional modelling to optimise reporting. Each fact and dimension had a defined grain that was derived from the clean schema to ensure consistency in downstream analysis. The modelling decisions below reflect key design choices made during this process.


## Modelling

The analytics tier implemented a star schema designed to calculate metrics and perform cohort analysis at query time. It was assumed during preliminary analysis that each customer account held at most one active subscription at any point in time. This was embedded in the first version of table definitions. Exploration of the source data invalidated this assumption and revealed that each account could hold multiple concurrent subscriptions across different plan tiers and billing frequencies. 

The first design iteration of the schema attempted to join source tables: churn_events to subscriptions through a composite account-month key, which caused fan-out where an account had more than one active subscription in a given month. For instance, a single churn event for an account would join to every active subscription in that same month, returning more than one row and inflating churn metrics. 

The second version of table definitions corrects this by decomposing the original fact table fact_subscription_revenue into two separate facts modelled at their natural grains.  These facts are joined at query time through dim_account, rather than in the model, to preserve grain integrity while still enabling cross-fact analysis:
- fact_subscriptions: one row per subscription; and
- fact_churn_events: one row per churn event (account-level)

The source churn_events table records a reason_code column containing values for customer churn, such as features, pricing, and budget. Storing this column directly in fact_churn_events as a raw string would expose BI tools to free-text grouping inconsistencies. reason_code was instead promoted to a dedicated dimension: dim_churn_reason which maps each reason_code value to a human-readable reason label and category.

This dimension was manually enriched to define two categories that reflect executive-level ownership: Commercial (pricing, budget, competitor codes) owned by Sales and Revenue teams; and Product & Experience (support, features) owned by Product teams. This design choice enables churn reason analysis to be surfaced at the category-level in dashboards without requiring string manipulation at query time. Having a normalised lookup also provides a controlled extension avenue if new reason codes were introduced in the future.


## Insights

**1. Enterprise accounts drive the majority of churn-based revenue loss**  

The Enterprise subscription tier dominates churn driven revenue loss across all segments; HealthTech and FinTech industries in the US have the greatest absolute revenue loss, with the HealthTech/US/Enterprise cohort alone accounting for $136k in churned MRR.

**2. Small segments can pose a disproportionate risk**  

The proportional percentage of revenue that churned out of the total MRR for each segment diverges significantly from absolute revenue loss. EdTech/DE/Enterprise has the highest proportional churn rate at 52% (nearly five times the median) with $5k in churned MRR, indicating an unsustainable churn rate within a small but high-risk segment.

**3. Refunds do not materially offset churn losses**  

Refunds offset less than 1% of churned MRR in every segment, indicating the net financial damage mirrors gross churn-based revenue loss with no meaningful cash recovery.

**4. High-value churn is concentrated in premium tiers**  

Seven of fifteen high-value segments (Pro and Enterprise tier) churn above the overall benchmark churn rate of 11.43%. Basic tier high-value accounts all churn below this benchmark representing a retention success pattern worth understanding. 

**5. No clear behavioural indicators warning churn risk**  

Behavioural data does not differentiate churned from retained subscriptions in this dataset; support and engagement profiles appear nearly identical up to point of churn. This suggests churn drivers are predominantly commercial rather than product-based, and that feature usage metrics alone may be insufficient as early warning signals. Note that the absence of behavioural divergence may reflect the synthetic nature of the source data rather than a genuine real-world pattern. 


## Recommendations

**1. Prioritise retention investment in HealthTech and FinTech Enterprise accounts in the US**  

These segments represent the greatest absolute loss and net revenue risk.

**2. Investigate EdTech/DE/Enterprise immediately**  

A 52% churn rate within a single cohort indicates a localised issue that warrants review.

**3. Reframe retention strategy around commercial signals**  

Behavioural data shows no meaningful divergence between churned and retained accounts. This suggests that pricing, budget, and competitive pressures are primary churn drivers and that product engagement metrics alone may be insufficient as an effective early warning system. 


## Dashboard

Interactive visualisation: **Churn Revenue Loss Analytics**
Built in Tableau Public to explore churn impact across segments.

[View Dashboard](https://public.tableau.com/app/profile/elaine.lay/viz/ChurnAnalyticsRevenueLoss/ChurnAnalyticsDashboard)


## Data Source & Attribution

Data: RavenStack (synthetic SaaS multi-table dataset)  
Source Credit: River at Rivalytics (Kaggle; MIT-like license)

This dataset was used to simulate a real-world churn analytics workflow, including subscription lifecycle tracking, churn events, and customer usage behaviour. 


## Appendix: Data Dictionary 

<details>
<summary><strong>View Data Dictionary & Metrics</strong></summary>


### Data Dictionary


**dim_date**

Purpose: creates a monthly calendar reference for time-based analysis  
Source:  generated month spine 

| Column            | Type     | Description                                                     |
|------------------|----------|-----------------------------------------------------------------|
| date_key         | int      | Unique identifier for each month (format: yyyymm)               |
| month_start      | date     | First day of calendar month                                     |
| month_number     | tinyint  | Calendar month number (1–12)                                    |
| month_name       | varchar  | Calendar month name (e.g. January)                              |
| quarter          | tinyint  | Calendar quarter (1–4)                                          |
| year             | smallint | Calendar year (e.g. 2024)                                       |
| is_current_month | boolean  | Indicates whether row represents most recent reporting month    |


**dim_account**

Purpose: stores customer attributes used to segment churn-based revenue loss  
Source:  churn_clean.accounts 

| Column             | Type    | Description                                      |
|--------------------|---------|--------------------------------------------------|
| account_key        | int     | Unique identifier for each account               |
| account_id         | varchar | Source system identifier for account             |
| account_name       | varchar | Customer name (company name)                     |
| industry           | varchar | Industry the customer operates in                |
| country            | char    | Country code where account is based              |
| initial_plan_tier  | enum    | Subscription tier at account creation            |


**dim_subscription**

Purpose: stores descriptive attributes of subscriptions for revenue loss analysis  
Source:  churn_clean.subscriptions

| Column             | Type    | Description                                         |
|--------------------|---------|-----------------------------------------------------|
| subscription_key   | int     | Unique identifier for each subscription             |
| subscription_id    | varchar | Source system identifier for subscription           |
| plan_tier          | enum    | Subscription tier (basic, pro, enterprise)          |
| seats              | int     | Number of licensed users                            |
| is_trial           | boolean | Indicates whether subscription is a trial           |
| billing_frequency  | enum    | Billing interval (monthly, annual)                  |


**dim_churn_reason**

Purpose: standardises reasons for churn for consistent reporting  
Source:  churn_clean.churn_events

| Column             | Type    | Description                                                        |
|--------------------|---------|--------------------------------------------------------------------|
| churn_reason_key   | int     | Unique identifier for each churn reason                            |
| reason_code        | varchar | Raw churn reason from source system                                |
| reason_label       | varchar | Human-readable churn reason description                            |
| reason_category    | varchar | Reporting category (e.g. Commercial, Product & Experience)         |


**fact_subscriptions**

Purpose: records subscription-level revenue and subscription lifecycle status  
Source:  churn_clean.subscriptions 

| Column                | Type    | Description                                                   |
|-----------------------|---------|---------------------------------------------------------------|
| subscription_key      | int     | Primary key; links to dim_subscription                        |
| account_key           | int     | Links subscription to customer account                        |
| start_date_key        | int     | Month subscription started                                    |
| end_date_key          | int     | Month subscription ended (if applicable)                      |
| mrr                   | decimal | Monthly recurring revenue                                     |
| is_churned            | tinyint | Indicates whether subscription has churned                    |
| is_upgraded           | tinyint | Indicates whether subscription was upgraded                   |
| is_downgraded         | tinyint | Indicates whether subscription was downgraded                 |
| auto_renew_flag       | tinyint | Indicates whether subscription renews automatically           |


**fact_churn_events**

Purpose: records details of each churn event and its direct financial impact   
Source:  churn_clean.churn_events

| Column                     | Type    | Description                                                   |
|----------------------------|---------|---------------------------------------------------------------|
| churn_event_key            | int     | Unique identifier for each churn event                        |
| churn_event_id             | varchar | Source system identifier for churn event                      |
| account_key                | int     | Links churn event to customer account                         |
| churn_date_key             | int     | Date churn occurred (format: yyyymm)                          |
| churn_reason_key           | int     | Links to churn reason                                         |
| refund_amount_usd          | decimal | Refund amount issued due to churn                             |
| is_reactivation            | tinyint | Indicates if account previously churned and returned          |
| preceding_upgrade_flag     | tinyint | Indicates churn followed a recent upgrade                     |
| preceding_downgrade_flag   | tinyint | Indicates churn followed a recent downgrade                   |


**fact_subscription_usage**

Purpose: tracks product usage and engagement at subscription-month level  
Source:  churn_clean.feature_usage + churn_clean.support_tickets 

| Column                              | Type     | Description                                              |
|-------------------------------------|----------|----------------------------------------------------------|
| date_key                            | int      | Month of usage record                                    |
| account_key                         | int      | Links usage to customer account                          |
| subscription_key                    | int      | Links usage to subscription                              |
| active_days                         | smallint | Number of active usage days                              |
| feature_adoption_count              | smallint | Number of distinct features used                         |
| total_usage_count                   | int      | Total number of usage events                             |
| total_usage_duration_secs           | int      | Total time spent using product                           |
| avg_usage_duration_secs             | decimal  | Average session duration                                 |
| total_error_count                   | int      | Total number of errors                                   |
| beta_feature_usage_count            | int      | Interactions with beta features                          |
| error_rate                          | decimal  | Proportion of usage events resulting in errors           |
| mom_active_days_delta               | smallint | Month-over-month change in active days                   |
| consecutive_low_engagement_months   | smallint | Consecutive months with low engagement                   |
| support_tickets_opened              | smallint | Number of support tickets raised                         |
| support_tickets_unresolved_eom      | smallint | Tickets unresolved at end of month                       |
| avg_resolution_hours                | decimal  | Average ticket resolution time                           |
| avg_satisfaction_score              | decimal  | Average customer satisfaction score                      |
| is_churned                          | tinyint  | Indicates whether subscription has churned               |


### Metric Dictionary

| Metric                   | Query Ref | Definition                                      | Business Relevance                          |
|--------------------------|-----------|-------------------------------------------------|---------------------------------------------|
| Churned MRR              | 1         | Sum of MRR where churn flag is true             | Absolute revenue lost per segment           |
| Revenue Churn Rate       | 2         | Churned MRR / Total MRR * 100                   | Proportional risk by segment                |
| Net Revenue Impact       | 3         | Churned MRR - refunds issued                    | True financial damage after cash outflows   |
| High Value Churn Rate    | 4         | Churn rate within top MRR quartile              | Retention prioritisation                    |
| Behavioural Divergence   | 5         | Avg metric delta: churned vs retained           | Leading indicators of churn risk            |


















