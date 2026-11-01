-- =====================================================================
-- MARKETING ANALYTICS DATABASE  (MySQL 8.0)     FILE 2 OF 2: REPORTS
-- ---------------------------------------------------------------------
-- RUN FILE 1 FIRST (marketing_analytics_setup.sql). It builds the data.
--
-- HOW TO USE THIS FILE IN MYSQL WORKBENCH
--   1. File > Open SQL Script...  and choose this file.
--   2. Do NOT run the whole file at once (it would open about 40 result
--      tabs). Click inside ONE query and press Ctrl+Enter to run just
--      that query.
--   3. Each report has a short note: what it answers and how to read it.
--
-- KEY TERMS
--   Impressions = times an ad was shown        Clicks = times it was clicked
--   CTR  = clicks / impressions                CPC  = spend / clicks
--   CPM  = cost per 1,000 impressions
--   ROAS = revenue / ad spend (3.0 means $3 back for every $1 spent)
--   CAC  = spend / new customers acquired
--   AOV  = average order value
--   CLV  = customer lifetime value (here: revenue per customer so far)
--
-- All money is in US dollars. "Today" in this project is 2026-10-12.
-- Revenue means COMPLETED orders only, after discounts.
-- =====================================================================

USE marketing_analytics;

-- =====================================================================
-- SECTION A: EXECUTIVE OVERVIEW
-- =====================================================================

-- A1) The big picture: one row of headline numbers
SELECT
    (SELECT ROUND(SUM(spend), 2) FROM ad_spend_daily)                                   AS total_ad_spend,
    (SELECT SUM(clicks) FROM ad_spend_daily)                                            AS total_clicks,
    (SELECT COUNT(*) FROM v_order_totals WHERE status = 'Completed')                    AS completed_orders,
    (SELECT ROUND(SUM(net_revenue), 2) FROM v_order_totals WHERE status = 'Completed')  AS revenue,
    (SELECT ROUND(AVG(net_revenue), 2) FROM v_order_totals WHERE status = 'Completed')  AS avg_order_value,
    (SELECT COUNT(*) FROM customers WHERE signup_date >= '2026-01-01')                  AS new_customers_2026,
    ROUND((SELECT SUM(net_revenue) FROM v_order_totals WHERE status = 'Completed')
          / (SELECT SUM(spend) FROM ad_spend_daily), 2)                                 AS overall_roas;

-- A2) Monthly revenue with growth and running total
--     growth_pct compares each month with the month before it.
--     October only has 12 days of data, so it looks small.
WITH monthly AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
           COUNT(*)                         AS orders,
           ROUND(SUM(net_revenue), 2)       AS revenue
    FROM v_order_totals
    WHERE status = 'Completed' AND order_date >= '2026-01-01'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT month,
       orders,
       revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
                 / LAG(revenue) OVER (ORDER BY month), 1) AS growth_pct,
       ROUND(SUM(revenue) OVER (ORDER BY month), 2)       AS running_total
FROM monthly;

-- A3) Actual results against the monthly targets
--     pct_of_target of 100 or more means the target was hit.
SELECT  DATE_FORMAT(t.target_month, '%Y-%m')                      AS month,
        t.revenue_target,
        ROUND(COALESCE(a.revenue, 0), 2)                          AS actual_revenue,
        ROUND(100 * COALESCE(a.revenue, 0) / t.revenue_target, 1) AS revenue_pct_of_target,
        t.new_customer_target,
        COALESCE(n.new_customers, 0)                              AS actual_new_customers,
        ROUND(100 * COALESCE(n.new_customers, 0) / t.new_customer_target, 1) AS customers_pct_of_target
FROM monthly_targets t
LEFT JOIN (SELECT DATE_FORMAT(order_date, '%Y-%m') AS m, SUM(net_revenue) AS revenue
           FROM v_order_totals
           WHERE status = 'Completed'
           GROUP BY DATE_FORMAT(order_date, '%Y-%m')) a
       ON a.m = DATE_FORMAT(t.target_month, '%Y-%m')
LEFT JOIN (SELECT DATE_FORMAT(signup_date, '%Y-%m') AS m, COUNT(*) AS new_customers
           FROM customers
           GROUP BY DATE_FORMAT(signup_date, '%Y-%m')) n
       ON n.m = DATE_FORMAT(t.target_month, '%Y-%m')
ORDER BY t.target_month;

-- =====================================================================
-- SECTION B: CHANNEL AND CAMPAIGN PERFORMANCE
-- =====================================================================

-- B1) Channel scorecard: which channels earn their budget?
SELECT  p.channel_name,
        ROUND(SUM(p.spend), 2)                                        AS spend,
        SUM(p.clicks)                                                 AS clicks,
        ROUND(100 * SUM(p.clicks) / NULLIF(SUM(p.impressions), 0), 2) AS ctr_pct,
        ROUND(SUM(p.spend) / NULLIF(SUM(p.clicks), 0), 2)             AS cpc,
        SUM(p.orders)                                                 AS orders,
        ROUND(SUM(p.revenue), 2)                                      AS revenue,
        ROUND(SUM(p.revenue) / NULLIF(SUM(p.spend), 0), 2)            AS roas,
        SUM(p.new_customers)                                          AS new_customers,
        ROUND(SUM(p.spend) / NULLIF(SUM(p.new_customers), 0), 2)      AS cac
FROM v_campaign_performance p
GROUP BY p.channel_name
ORDER BY roas DESC;

-- B2) Are our channels beating industry benchmarks?
SELECT  ch.channel_name,
        ROUND(100 * SUM(s.clicks) / SUM(s.impressions), 2)  AS actual_ctr_pct,
        ROUND(100 * ch.benchmark_ctr, 2)                    AS benchmark_ctr_pct,
        ROUND(1000 * SUM(s.spend) / SUM(s.impressions), 2)  AS actual_cpm,
        ch.benchmark_cpm
FROM ad_spend_daily s
JOIN campaigns c ON c.campaign_id = s.campaign_id
JOIN channels ch ON ch.channel_id = c.channel_id
GROUP BY ch.channel_id, ch.channel_name, ch.benchmark_ctr, ch.benchmark_cpm
ORDER BY ch.channel_name;

-- B3) Top 10 campaigns by ROAS
SELECT campaign_name, channel_name, objective, spend, revenue, roas
FROM v_campaign_performance
WHERE spend > 0
ORDER BY roas DESC
LIMIT 10;

-- B4) Weakest 5 sales and traffic campaigns by ROAS
--     (Awareness campaigns are left out because they are judged on reach.)
SELECT campaign_name, channel_name, objective, spend, revenue, roas
FROM v_campaign_performance
WHERE spend > 0 AND objective <> 'Awareness'
ORDER BY roas ASC
LIMIT 5;

-- B5) Rank campaigns inside their own channel
SELECT  channel_name,
        campaign_name,
        spend,
        revenue,
        roas,
        RANK() OVER (PARTITION BY channel_name ORDER BY roas DESC) AS rank_in_channel
FROM v_campaign_performance
WHERE spend > 0 AND objective <> 'Awareness'
ORDER BY channel_name, rank_in_channel;

-- B6) Budget pacing for campaigns that are running now
--     Compares how much budget is used with how much time has passed.
SELECT  t.campaign_name,
        t.budget,
        t.spend,
        t.pct_budget_used,
        t.pct_time_elapsed,
        CASE WHEN t.pct_budget_used - t.pct_time_elapsed >  10 THEN 'Spending too fast'
             WHEN t.pct_budget_used - t.pct_time_elapsed < -10 THEN 'Spending too slow'
             ELSE 'On track'
        END AS pacing
FROM (
    SELECT c.campaign_name,
           c.budget,
           p.spend,
           ROUND(100 * p.spend / c.budget, 1) AS pct_budget_used,
           ROUND(100 * LEAST(1, (DATEDIFF('2026-10-12', c.start_date) + 1)
                              / (DATEDIFF(c.end_date, c.start_date) + 1)), 1) AS pct_time_elapsed
    FROM campaigns c
    JOIN v_campaign_performance p ON p.campaign_id = c.campaign_id
    WHERE c.status = 'Active'
) t
ORDER BY t.pct_budget_used DESC;

-- B7) Scale, keep, or fix? A simple recommendation for every campaign
SELECT  campaign_name,
        channel_name,
        objective,
        spend,
        revenue,
        roas,
        CASE WHEN spend = 0                 THEN 'No spend yet'
             WHEN objective = 'Awareness'   THEN 'Judge on reach, not ROAS'
             WHEN roas >= 4                 THEN 'Scale up'
             WHEN roas >= 2                 THEN 'Keep running'
             WHEN roas >= 1                 THEN 'Optimize'
             ELSE 'Cut or fix'
        END AS recommendation
FROM v_campaign_performance
ORDER BY roas DESC;

-- B8) Deep dive on one campaign (change the number to look at another)
--     Shows the overall numbers, then week by week spend and clicks.
CALL sp_campaign_report(4);

-- B9) How many orders came from campaigns, and how many came direct?
SELECT  IF(campaign_id IS NULL, 'Direct (no campaign)', 'Credited to a campaign') AS source,
        COUNT(*)                          AS orders,
        ROUND(SUM(net_revenue), 2)        AS revenue,
        ROUND(100 * SUM(net_revenue) / (SELECT SUM(net_revenue) FROM v_order_totals
                                        WHERE status = 'Completed'), 1) AS pct_of_revenue
FROM v_order_totals
WHERE status = 'Completed'
GROUP BY IF(campaign_id IS NULL, 'Direct (no campaign)', 'Credited to a campaign');

-- B10) Which weekday sells the most?
SELECT  DAYNAME(order_date)          AS weekday,
        COUNT(*)                     AS orders,
        ROUND(SUM(net_revenue), 2)   AS revenue
FROM v_order_totals
WHERE status = 'Completed'
GROUP BY DAYNAME(order_date), WEEKDAY(order_date)
ORDER BY WEEKDAY(order_date);

-- =====================================================================
-- SECTION C: CUSTOMERS
-- =====================================================================

-- C1) Customer value by acquisition channel (2026 customers)
--     Cheap customers are not always the best customers. Compare this
--     with the CAC column in B1.
SELECT  ch.channel_name,
        COUNT(*)                          AS customers,
        ROUND(AVG(cs.orders), 2)          AS avg_orders,
        ROUND(AVG(cs.revenue), 2)         AS avg_revenue_per_customer
FROM v_customer_summary cs
JOIN channels ch ON ch.channel_id = cs.acquisition_channel_id
WHERE cs.signup_date >= '2026-01-01'
GROUP BY ch.channel_id, ch.channel_name
ORDER BY avg_revenue_per_customer DESC;

-- C2) Repeat purchase rate: of customers who bought, how many bought again?
SELECT  SUM(orders >= 1)                              AS buyers,
        SUM(orders >= 2)                              AS repeat_buyers,
        ROUND(100 * SUM(orders >= 2) / SUM(orders >= 1), 1) AS repeat_rate_pct
FROM v_customer_summary;

-- C3) Signup cohorts: for each signup month, how many bought, and how many bought again?
SELECT  DATE_FORMAT(signup_date, '%Y-%m')                   AS signup_month,
        COUNT(*)                                            AS customers,
        SUM(orders >= 1)                                    AS buyers,
        ROUND(100 * SUM(orders >= 1) / COUNT(*), 1)         AS pct_bought,
        SUM(orders >= 2)                                    AS repeat_buyers,
        ROUND(100 * SUM(orders >= 2) / COUNT(*), 1)         AS pct_repeat
FROM v_customer_summary
WHERE signup_date >= '2026-01-01'
GROUP BY DATE_FORMAT(signup_date, '%Y-%m')
ORDER BY signup_month;

-- C4) RFM segmentation: group buyers by Recency, Frequency, and Money spent
--     Each customer gets a score from 1 (low) to 4 (high) on each measure.
SELECT  CASE WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions'
             WHEN r_score >= 3 AND f_score >= 2                  THEN 'Loyal'
             WHEN r_score <= 2 AND f_score >= 3                  THEN 'At risk'
             WHEN r_score = 1                                    THEN 'Lost'
             ELSE 'Potential'
        END                                AS segment,
        COUNT(*)                           AS customers,
        ROUND(AVG(monetary), 2)            AS avg_revenue,
        ROUND(AVG(frequency), 1)           AS avg_orders,
        ROUND(AVG(recency_days))           AS avg_days_since_last_order
FROM (
    SELECT  customer_id, recency_days, frequency, monetary,
            NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
            NTILE(4) OVER (ORDER BY frequency)         AS f_score,
            NTILE(4) OVER (ORDER BY monetary)          AS m_score
    FROM (
        SELECT customer_id,
               DATEDIFF('2026-10-12', last_order) AS recency_days,
               orders                             AS frequency,
               revenue                            AS monetary
        FROM v_customer_summary
        WHERE orders > 0
    ) base
) scored
GROUP BY CASE WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions'
              WHEN r_score >= 3 AND f_score >= 2                  THEN 'Loyal'
              WHEN r_score <= 2 AND f_score >= 3                  THEN 'At risk'
              WHEN r_score = 1                                    THEN 'Lost'
              ELSE 'Potential'
         END
ORDER BY customers DESC;

-- C5) Top 10 customers by revenue
SELECT customer, city, country, orders, revenue, last_order
FROM v_customer_summary
ORDER BY revenue DESC
LIMIT 10;

-- C6) Revenue by country
SELECT  country,
        COUNT(*)                          AS customers,
        SUM(orders)                       AS orders,
        ROUND(SUM(revenue), 2)            AS revenue,
        ROUND(SUM(revenue) / COUNT(*), 2) AS revenue_per_customer
FROM v_customer_summary
GROUP BY country
ORDER BY revenue DESC;

-- C7) Revenue by age group
SELECT  age_group,
        COUNT(*)                          AS customers,
        ROUND(SUM(revenue), 2)            AS revenue,
        ROUND(AVG(avg_order_value), 2)    AS avg_order_value
FROM v_customer_summary
GROUP BY age_group
ORDER BY age_group;

-- =====================================================================
-- SECTION D: PRODUCTS
-- =====================================================================

-- D1) Category performance with profit margin (after discounts)
SELECT  p.category,
        SUM(oi.quantity)                                                         AS units_sold,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - o.discount_pct / 100)), 2)  AS revenue,
        ROUND(SUM(oi.quantity * (oi.unit_price * (1 - o.discount_pct / 100) - p.cost)), 2) AS profit,
        ROUND(100 * SUM(oi.quantity * (oi.unit_price * (1 - o.discount_pct / 100) - p.cost))
                  / SUM(oi.quantity * oi.unit_price * (1 - o.discount_pct / 100)), 1)      AS margin_pct
FROM order_items oi
JOIN orders o   ON o.order_id   = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'Completed'
GROUP BY p.category
ORDER BY revenue DESC;

-- D2) Top 10 products by revenue
SELECT  p.product_name,
        p.category,
        SUM(oi.quantity)                                                         AS units_sold,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - o.discount_pct / 100)), 2)  AS revenue
FROM order_items oi
JOIN orders o   ON o.order_id   = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'Completed'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10;

-- D3) Do discounts pay off? Compare orders with and without a discount
SELECT  discount_pct,
        COUNT(*)                   AS orders,
        ROUND(AVG(net_revenue), 2) AS avg_order_value,
        ROUND(SUM(net_revenue), 2) AS revenue
FROM v_order_totals
WHERE status = 'Completed'
GROUP BY discount_pct
ORDER BY discount_pct;

-- =====================================================================
-- SECTION E: LEADS, SOCIAL MEDIA, AND A/B TESTS
-- =====================================================================

-- E1) The lead funnel: how many leads reach each stage?
SELECT  stage,
        COUNT(*)                                                   AS leads,
        ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM leads), 1)    AS pct_of_all_leads
FROM leads
GROUP BY stage
ORDER BY FIELD(stage, 'Lead', 'MQL', 'SQL', 'Customer', 'Lost');

-- E2) Lead quality and cost by campaign
--     cost_per_lead = spend / leads.  Lower is better.
SELECT  c.campaign_name,
        c.objective,
        COUNT(*)                                                   AS leads,
        SUM(l.stage = 'Customer')                                  AS became_customers,
        ROUND(100 * SUM(l.stage = 'Customer') / COUNT(*), 1)       AS lead_to_customer_pct,
        p.spend,
        ROUND(p.spend / COUNT(*), 2)                               AS cost_per_lead
FROM leads l
JOIN campaigns c                 ON c.campaign_id = l.campaign_id
JOIN v_campaign_performance p    ON p.campaign_id = l.campaign_id
GROUP BY c.campaign_id, c.campaign_name, c.objective, p.spend
ORDER BY cost_per_lead;

-- E3) Which type of social post gets the most engagement?
--     engagement rate = (likes + comments + shares) / reach
SELECT  content_type,
        COUNT(*)                                                         AS posts,
        ROUND(AVG(reach))                                                AS avg_reach,
        ROUND(100 * SUM(likes + comments + shares) / SUM(reach), 2)      AS engagement_rate_pct,
        ROUND(AVG(link_clicks))                                          AS avg_link_clicks
FROM social_posts
GROUP BY content_type
ORDER BY engagement_rate_pct DESC;

-- E4) Social performance by channel
SELECT  ch.channel_name,
        COUNT(*)                                                         AS posts,
        SUM(sp.reach)                                                    AS total_reach,
        ROUND(100 * SUM(sp.likes + sp.comments + sp.shares) / SUM(sp.reach), 2) AS engagement_rate_pct,
        SUM(sp.link_clicks)                                              AS link_clicks
FROM social_posts sp
JOIN channels ch ON ch.channel_id = sp.channel_id
GROUP BY ch.channel_id, ch.channel_name
ORDER BY engagement_rate_pct DESC;

-- E5) A/B test results with a significance check
--     z_score above 1.96 (or below -1.96) means we can be about 95 percent
--     sure the difference is real and not luck.
SELECT  t.*,
        CASE WHEN ABS(t.z_score) >= 1.96 THEN 'Yes'  ELSE 'No' END AS significant,
        CASE WHEN ABS(t.z_score) <  1.96 THEN 'No clear winner'
             WHEN t.rate_b > t.rate_a    THEN 'Version B wins'
             ELSE 'Version A wins'
        END AS result
FROM (
    SELECT  a.test_name,
            ROUND(100 * a.conversions / a.visitors, 2)  AS rate_a,
            ROUND(100 * b.conversions / b.visitors, 2)  AS rate_b,
            ROUND(100 * ((b.conversions / b.visitors) / (a.conversions / a.visitors) - 1), 1) AS lift_pct,
            ROUND(((b.conversions / b.visitors) - (a.conversions / a.visitors)) /
                  SQRT(((a.conversions + b.conversions) / (a.visitors + b.visitors))
                       * (1 - (a.conversions + b.conversions) / (a.visitors + b.visitors))
                       * (1 / a.visitors + 1 / b.visitors)), 2) AS z_score
    FROM ab_tests a
    JOIN ab_tests b ON b.test_name = a.test_name AND a.variant = 'A' AND b.variant = 'B'
) t
ORDER BY t.test_name;

-- =====================================================================
-- SECTION F: DATA VALIDATION
-- Good analysts check the data BEFORE sharing a report. Each query
-- below looks for a common problem. A clean database returns NO ROWS
-- (or zeros in F9). Run these after loading any new data.
-- =====================================================================

-- F1) Customers entered twice (same email, ignoring capital letters)
SELECT LOWER(email) AS email, COUNT(*) AS times_entered
FROM customers
GROUP BY LOWER(email)
HAVING COUNT(*) > 1;

-- F2) Campaigns that spent more than 5 percent over budget
SELECT c.campaign_id, c.campaign_name, c.budget, ROUND(SUM(s.spend), 2) AS spend
FROM campaigns c
JOIN ad_spend_daily s ON s.campaign_id = c.campaign_id
GROUP BY c.campaign_id, c.campaign_name, c.budget
HAVING SUM(s.spend) > c.budget * 1.05;

-- F3) Days where clicks are higher than impressions (impossible)
SELECT campaign_id, spend_date, impressions, clicks
FROM ad_spend_daily
WHERE clicks > impressions;

-- F4) Orders credited to a campaign outside the campaign's dates
SELECT o.order_id, o.order_date, c.campaign_name, c.start_date, c.end_date
FROM orders o
JOIN campaigns c ON c.campaign_id = o.campaign_id
WHERE o.order_date < c.start_date OR o.order_date > c.end_date;

-- F5) Orders placed before the customer signed up
SELECT o.order_id, o.customer_id, o.order_date, cu.signup_date
FROM orders o
JOIN customers cu ON cu.customer_id = o.customer_id
WHERE o.order_date < cu.signup_date;

-- F6) Order items with a zero price, or a price that differs from the product list price
SELECT oi.order_item_id, oi.order_id, p.product_name, p.price AS list_price, oi.unit_price
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
WHERE oi.unit_price = 0 OR oi.unit_price <> p.price;

-- F7) Campaigns whose status does not match their dates
SELECT campaign_id, campaign_name, status, start_date, end_date
FROM campaigns
WHERE (status = 'Active'    AND (end_date < '2026-10-12' OR start_date > '2026-10-12'))
   OR (status = 'Completed' AND end_date >= '2026-10-12')
   OR (status = 'Draft'     AND start_date <= '2026-10-12');

-- F8) Customers credited to a campaign that was not running when they signed up,
--     or whose acquisition channel does not match the campaign's channel
SELECT cu.customer_id, cu.signup_date, c.campaign_name, c.start_date, c.end_date,
       cu.acquisition_channel_id, c.channel_id AS campaign_channel_id
FROM customers cu
JOIN campaigns c ON c.campaign_id = cu.acquisition_campaign_id
WHERE cu.signup_date < c.start_date
   OR cu.signup_date > c.end_date
   OR cu.acquisition_channel_id <> c.channel_id;

-- F9) Validation summary: number of problems found by each check
SELECT 'Duplicate customers' AS check_name, COUNT(*) AS problems FROM (
    SELECT 1 FROM customers GROUP BY LOWER(email) HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'Campaigns over budget (5 percent)', COUNT(*) FROM (
    SELECT 1 FROM campaigns c JOIN ad_spend_daily s ON s.campaign_id = c.campaign_id
    GROUP BY c.campaign_id, c.budget HAVING SUM(s.spend) > c.budget * 1.05) b
UNION ALL
SELECT 'Clicks higher than impressions', COUNT(*) FROM ad_spend_daily WHERE clicks > impressions
UNION ALL
SELECT 'Orders outside campaign dates', COUNT(*) FROM orders o
JOIN campaigns c ON c.campaign_id = o.campaign_id
WHERE o.order_date < c.start_date OR o.order_date > c.end_date
UNION ALL
SELECT 'Orders before customer signup', COUNT(*) FROM orders o
JOIN customers cu ON cu.customer_id = o.customer_id
WHERE o.order_date < cu.signup_date
UNION ALL
SELECT 'Order items with odd prices', COUNT(*) FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
WHERE oi.unit_price = 0 OR oi.unit_price <> p.price
UNION ALL
SELECT 'Campaign status mismatches', COUNT(*) FROM campaigns
WHERE (status = 'Active'    AND (end_date < '2026-10-12' OR start_date > '2026-10-12'))
   OR (status = 'Completed' AND end_date >= '2026-10-12')
   OR (status = 'Draft'     AND start_date <= '2026-10-12')
UNION ALL
SELECT 'Customers with campaign mismatch', COUNT(*) FROM customers cu
JOIN campaigns c ON c.campaign_id = cu.acquisition_campaign_id
WHERE cu.signup_date < c.start_date OR cu.signup_date > c.end_date
   OR cu.acquisition_channel_id <> c.channel_id;
