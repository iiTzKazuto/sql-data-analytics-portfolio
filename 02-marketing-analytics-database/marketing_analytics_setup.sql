-- =====================================================================
-- MARKETING ANALYTICS DATABASE  (MySQL 8.0)       FILE 1 OF 2: SETUP
-- ---------------------------------------------------------------------
-- WHAT THIS PROJECT IS
--   The database of an online lifestyle store, seen through the eyes of
--   a marketing analyst. It tracks 8 marketing channels, 31 campaigns,
--   daily ad spend, customers, orders, leads, social posts, A/B tests,
--   and monthly targets. About 17,000 rows are generated for you.
--
--   The data is generated to behave like real marketing data: busy and
--   quiet months, strong and weak channels, repeat buyers, one-time
--   buyers, and campaigns that win or lose. File 2 contains the reports
--   and data checks a marketing analyst would run every week.
--
-- HOW TO RUN THIS FILE IN MYSQL WORKBENCH
--   1. File > Open SQL Script...  and choose this file.
--   2. Press Ctrl+Shift+Enter  (runs the WHOLE script, top to bottom).
--      It takes a few seconds. Wait until the last table of row counts
--      appears.
--   3. In the Schemas panel, right-click and choose "Refresh All".
--      You will see a new database: marketing_analytics.
--   4. Now open FILE 2: marketing_analytics_reports.sql
--      and run its queries ONE AT A TIME (click inside a query, then
--      press Ctrl+Enter). Do not run the whole of file 2 at once.
--
-- NOTE: This creates a NEW database called marketing_analytics, so your
-- other databases are untouched. Running this file again deletes
-- marketing_analytics and rebuilds it from scratch.
--
-- All money is in US dollars. "Today" in this project is 2026-10-12.
-- =====================================================================

DROP DATABASE IF EXISTS marketing_analytics;
CREATE DATABASE marketing_analytics;
USE marketing_analytics;

-- Allows the generator queries below to count up to a few thousand rows
SET SESSION cte_max_recursion_depth = 10000;

-- ---------------------------------------------------------------------
-- 1. CHANNELS
--    benchmark_cpm : typical cost per 1,000 impressions for this channel
--    benchmark_ctr : typical click-through rate (0.0280 = 2.8 percent)
--    conversion_index : how well the channel turns people into buyers
--                       compared with average (1.0 = average)
-- ---------------------------------------------------------------------
CREATE TABLE channels (
    channel_id       INT AUTO_INCREMENT PRIMARY KEY,
    channel_name     VARCHAR(50) NOT NULL UNIQUE,
    channel_type     ENUM('Paid', 'Owned', 'Partner') NOT NULL,
    benchmark_cpm    DECIMAL(6,2) NOT NULL,
    benchmark_ctr    DECIMAL(5,4) NOT NULL,
    conversion_index DECIMAL(3,1) NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. CAMPAIGNS
--    daily_budget is calculated automatically from budget and dates
-- ---------------------------------------------------------------------
CREATE TABLE campaigns (
    campaign_id    INT AUTO_INCREMENT PRIMARY KEY,
    campaign_name  VARCHAR(100) NOT NULL,
    channel_id     INT NOT NULL,
    objective      ENUM('Awareness', 'Traffic', 'Leads', 'Sales') NOT NULL,
    start_date     DATE NOT NULL,
    end_date       DATE NOT NULL,
    budget         DECIMAL(10,2) NOT NULL CHECK (budget > 0),
    status         ENUM('Draft', 'Active', 'Paused', 'Completed') NOT NULL,
    daily_budget   DECIMAL(10,2) GENERATED ALWAYS AS
                   (ROUND(budget / (DATEDIFF(end_date, start_date) + 1), 2)) STORED,
    CHECK (end_date >= start_date),
    FOREIGN KEY (channel_id) REFERENCES channels(channel_id)
);

-- ---------------------------------------------------------------------
-- 3. AD_SPEND_DAILY (one row per campaign per day)
-- ---------------------------------------------------------------------
CREATE TABLE ad_spend_daily (
    campaign_id INT NOT NULL,
    spend_date  DATE NOT NULL,
    impressions INT NOT NULL,
    clicks      INT NOT NULL,
    spend       DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (campaign_id, spend_date),
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id)
);

-- ---------------------------------------------------------------------
-- 4. CUSTOMERS
--    acquisition_campaign_id is empty for older customers we cannot
--    trace to a campaign.
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id             INT AUTO_INCREMENT PRIMARY KEY,
    first_name              VARCHAR(50)  NOT NULL,
    last_name               VARCHAR(50)  NOT NULL,
    email                   VARCHAR(100),
    city                    VARCHAR(50),
    country                 VARCHAR(50),
    age_group               ENUM('18-24', '25-34', '35-44', '45-54', '55+') NOT NULL,
    signup_date             DATE NOT NULL,
    acquisition_channel_id  INT,
    acquisition_campaign_id INT,
    email_opt_in            TINYINT(1) NOT NULL DEFAULT 1,
    FOREIGN KEY (acquisition_channel_id)  REFERENCES channels(channel_id),
    FOREIGN KEY (acquisition_campaign_id) REFERENCES campaigns(campaign_id)
);

-- ---------------------------------------------------------------------
-- 5. PRODUCTS
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id   INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category     ENUM('Apparel', 'Accessories', 'Home', 'Beauty') NOT NULL,
    price        DECIMAL(8,2) NOT NULL CHECK (price > 0),
    cost         DECIMAL(8,2) NOT NULL CHECK (cost >= 0)
);

-- ---------------------------------------------------------------------
-- 6. ORDERS
--    campaign_id is the campaign the order is credited to.
--    Empty means the customer came directly (no campaign).
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id     INT AUTO_INCREMENT PRIMARY KEY,
    customer_id  INT NOT NULL,
    order_date   DATE NOT NULL,
    campaign_id  INT,
    status       ENUM('Completed', 'Cancelled', 'Refunded') NOT NULL,
    discount_pct DECIMAL(4,1) NOT NULL DEFAULT 0,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id)
);

-- ---------------------------------------------------------------------
-- 7. ORDER_ITEMS
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id      INT NOT NULL,
    product_id    INT NOT NULL,
    quantity      INT NOT NULL CHECK (quantity > 0),
    unit_price    DECIMAL(8,2) NOT NULL CHECK (unit_price >= 0),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ---------------------------------------------------------------------
-- 8. LEADS (people who signed up or enquired, and how far they got)
-- ---------------------------------------------------------------------
CREATE TABLE leads (
    lead_id     INT AUTO_INCREMENT PRIMARY KEY,
    campaign_id INT NOT NULL,
    lead_date   DATE NOT NULL,
    stage       ENUM('Lead', 'MQL', 'SQL', 'Customer', 'Lost') NOT NULL,
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id)
);

-- ---------------------------------------------------------------------
-- 9. SOCIAL_POSTS
-- ---------------------------------------------------------------------
CREATE TABLE social_posts (
    post_id      INT AUTO_INCREMENT PRIMARY KEY,
    campaign_id  INT NOT NULL,
    channel_id   INT NOT NULL,
    post_date    DATE NOT NULL,
    content_type ENUM('Image', 'Video', 'Carousel', 'Story', 'Reel', 'Text') NOT NULL,
    reach        INT NOT NULL,
    likes        INT NOT NULL,
    comments     INT NOT NULL,
    shares       INT NOT NULL,
    link_clicks  INT NOT NULL,
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id),
    FOREIGN KEY (channel_id)  REFERENCES channels(channel_id)
);

-- ---------------------------------------------------------------------
-- 10. AB_TESTS (two versions of something, A and B, compared)
-- ---------------------------------------------------------------------
CREATE TABLE ab_tests (
    ab_test_id  INT AUTO_INCREMENT PRIMARY KEY,
    test_name   VARCHAR(100) NOT NULL,
    campaign_id INT NOT NULL,
    variant     CHAR(1) NOT NULL,
    visitors    INT NOT NULL,
    conversions INT NOT NULL,
    UNIQUE (test_name, variant),
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id)
);

-- ---------------------------------------------------------------------
-- 11. MONTHLY_TARGETS (goals to compare actual results against)
-- ---------------------------------------------------------------------
CREATE TABLE monthly_targets (
    target_month        DATE PRIMARY KEY,      -- first day of the month
    revenue_target      DECIMAL(12,2) NOT NULL,
    new_customer_target INT NOT NULL
);

-- =====================================================================
-- SAMPLE DATA
-- =====================================================================

INSERT INTO channels (channel_id, channel_name, channel_type, benchmark_cpm, benchmark_ctr, conversion_index) VALUES
    (1, 'Email',              'Owned',   2.00, 0.0280, 3.0),
    (2, 'Facebook Ads',       'Paid',    9.00, 0.0110, 1.0),
    (3, 'Instagram Ads',      'Paid',   11.00, 0.0090, 0.8),
    (4, 'Google Search Ads',  'Paid',   28.00, 0.0450, 1.6),
    (5, 'TikTok Ads',         'Paid',    7.00, 0.0080, 0.6),
    (6, 'YouTube Ads',        'Paid',   10.00, 0.0060, 0.7),
    (7, 'Influencer',         'Partner',15.00, 0.0150, 1.2),
    (8, 'Organic Search',     'Owned',   1.50, 0.0300, 4.0);

INSERT INTO campaigns (campaign_id, campaign_name, channel_id, objective, start_date, end_date, budget, status) VALUES
    (1,  'New Year Welcome Emails',      1, 'Leads',     '2026-01-04', '2026-01-31',  1500.00, 'Completed'),
    (2,  'Valentine Gift Guide',         2, 'Sales',     '2026-01-26', '2026-02-14',  6000.00, 'Completed'),
    (3,  'Brand Awareness Q1',           6, 'Awareness', '2026-01-10', '2026-03-10', 12000.00, 'Completed'),
    (4,  'Search: Core Keywords Q1',     4, 'Traffic',   '2026-01-05', '2026-03-31', 15000.00, 'Completed'),
    (5,  'Spring Launch Teasers',        3, 'Awareness', '2026-02-15', '2026-03-31',  7000.00, 'Completed'),
    (6,  'TikTok Trend Challenge',       5, 'Awareness', '2026-02-20', '2026-04-10',  9000.00, 'Completed'),
    (7,  'Influencer Spring Haul',       7, 'Sales',     '2026-03-01', '2026-04-15', 10000.00, 'Completed'),
    (8,  'Spring Sale Email Series',     1, 'Sales',     '2026-03-15', '2026-04-15',  2500.00, 'Completed'),
    (9,  'Retargeting: Cart Abandoners', 2, 'Sales',     '2026-03-20', '2026-06-30',  8000.00, 'Completed'),
    (10, 'Search: Competitor Terms',     4, 'Leads',     '2026-04-01', '2026-06-15', 11000.00, 'Completed'),
    (11, 'Mothers Day Promo',            3, 'Sales',     '2026-04-20', '2026-05-10',  5000.00, 'Completed'),
    (12, 'YouTube How-To Series',        6, 'Traffic',   '2026-04-15', '2026-06-30',  9500.00, 'Completed'),
    (13, 'Summer Preview Reels',         3, 'Awareness', '2026-05-10', '2026-06-20',  6500.00, 'Completed'),
    (14, 'Lead Magnet: Free Guide',      2, 'Leads',     '2026-05-01', '2026-06-30',  7500.00, 'Completed'),
    (15, 'Influencer Summer Series',     7, 'Sales',     '2026-05-25', '2026-07-15', 12000.00, 'Completed'),
    (16, 'Mid-Year Sale Email',          1, 'Sales',     '2026-06-15', '2026-07-10',  2000.00, 'Completed'),
    (17, 'TikTok Summer Flash',          5, 'Sales',     '2026-06-01', '2026-07-31',  8500.00, 'Completed'),
    (18, 'Search: Brand Defense',        4, 'Traffic',   '2026-06-01', '2026-09-30',  6000.00, 'Completed'),
    (19, 'Back to School Search',        4, 'Sales',     '2026-07-10', '2026-08-31', 10500.00, 'Completed'),
    (20, 'Back to School Social',        2, 'Sales',     '2026-07-15', '2026-08-31',  9000.00, 'Completed'),
    (21, 'Newsletter Growth Drive',      1, 'Leads',     '2026-07-01', '2026-09-15',  1800.00, 'Completed'),
    (22, 'Blog and SEO Content Push',    8, 'Traffic',   '2026-01-15', '2026-09-30',  4000.00, 'Completed'),
    (23, 'Loyalty Program Launch',       1, 'Sales',     '2026-08-01', '2026-09-10',  2200.00, 'Completed'),
    (24, 'YouTube Product Demos',        6, 'Leads',     '2026-08-10', '2026-10-31',  8000.00, 'Active'),
    (25, 'Instagram Fall Collection',    3, 'Awareness', '2026-09-01', '2026-11-15',  9000.00, 'Active'),
    (26, 'Influencer Fall Haul',         7, 'Sales',     '2026-09-05', '2026-10-31', 11000.00, 'Active'),
    (27, 'TikTok Fall Challenge',        5, 'Awareness', '2026-09-10', '2026-10-31',  7000.00, 'Active'),
    (28, 'Search: Holiday Preview',      4, 'Traffic',   '2026-09-15', '2026-12-15', 14000.00, 'Active'),
    (29, 'Facebook Lead Forms Fall',     2, 'Leads',     '2026-09-12', '2026-10-31',  6500.00, 'Active'),
    (30, 'Halloween Email Series',       1, 'Sales',     '2026-10-01', '2026-10-31',  1500.00, 'Active'),
    (31, 'Winter Preview Launch',        4, 'Sales',     '2026-11-15', '2026-12-31',  9000.00, 'Draft');

INSERT INTO products (product_id, product_name, category, price, cost) VALUES
    (1,  'Classic Cotton Tee',       'Apparel',     24.00,  9.00),
    (2,  'Everyday Hoodie',          'Apparel',     58.00, 24.00),
    (3,  'Slim Fit Jeans',           'Apparel',     72.00, 30.00),
    (4,  'Linen Summer Dress',       'Apparel',     65.00, 26.00),
    (5,  'Windbreaker Jacket',       'Apparel',     89.00, 38.00),
    (6,  'Canvas Tote Bag',          'Accessories', 28.00, 10.00),
    (7,  'Leather Wallet',           'Accessories', 45.00, 16.00),
    (8,  'Sport Cap',                'Accessories', 19.00,  6.00),
    (9,  'Sunglasses',               'Accessories', 54.00, 18.00),
    (10, 'Stainless Water Bottle',   'Accessories', 26.00,  9.00),
    (11, 'Scented Candle Set',       'Home',        32.00, 11.00),
    (12, 'Throw Blanket',            'Home',        48.00, 18.00),
    (13, 'Ceramic Mug Set',          'Home',        36.00, 13.00),
    (14, 'Wall Art Print',           'Home',        41.00, 12.00),
    (15, 'Desk Organizer',           'Home',        29.00, 10.00),
    (16, 'Hydrating Face Serum',     'Beauty',      38.00, 10.00),
    (17, 'Daily Sunscreen SPF50',    'Beauty',      22.00,  6.00),
    (18, 'Lip Balm Trio',            'Beauty',      15.00,  4.00),
    (19, 'Clay Face Mask',           'Beauty',      27.00,  8.00),
    (20, 'Vitamin C Cream',          'Beauty',      44.00, 13.00);

-- Name lists used only to build realistic customer names (deleted at the end)
CREATE TABLE name_pool_first (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50));
CREATE TABLE name_pool_last  (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50));

INSERT INTO name_pool_first (name) VALUES
    ('Miguel'),('Angela'),('Rafael'),('Patricia'),('Joshua'),('Camille'),('Gabriel'),('Bianca'),
    ('Marco'),('Nicole'),('Ethan'),('Chloe'),('Ryan'),('Hannah'),('Kevin'),('Sarah'),
    ('Jason'),('Rachel'),('Carlo'),('Andrea'),('Daniel'),('Olivia'),('Jacob'),('Megan'),
    ('Adrian'),('Tiffany'),('Justin'),('Katrina'),('Brandon'),('Jasmine'),('Leo'),('Natalie'),
    ('Vincent'),('Isabel'),('Aaron'),('Clarisse'),('Nathan'),('Erica'),('Dominic'),('Francesca');

INSERT INTO name_pool_last (name) VALUES
    ('Santos'),('Reyes'),('Cruz'),('Garcia'),('Mendoza'),('Tan'),('Lim'),('Chua'),
    ('Villanueva'),('Ramos'),('Torres'),('Flores'),('Bautista'),('Aquino'),('Navarro'),('Smith'),
    ('Johnson'),('Brown'),('Taylor'),('Anderson'),('Thomas'),('Moore'),('Martin'),('Jackson'),
    ('Thompson'),('White'),('Lopez'),('Lee'),('Gonzalez'),('Harris'),('Clark'),('Lewis'),
    ('Robinson'),('Walker'),('Young'),('Allen'),('King'),('Wright'),('Scott'),('Green');

-- ---------------------------------------------------------------------
-- DAILY AD SPEND
-- Each campaign spends roughly its daily budget every day until its end
-- date (or until today). Impressions and clicks follow the channel
-- benchmarks, but each campaign does a bit better or worse than the
-- benchmark, with some day-to-day variation.
-- ---------------------------------------------------------------------
INSERT INTO ad_spend_daily (campaign_id, spend_date, impressions, clicks, spend)
WITH RECURSIVE days AS (
    SELECT DATE('2026-01-01') AS d
    UNION ALL
    SELECT d + INTERVAL 1 DAY FROM days WHERE d < '2026-10-12'
)
SELECT i.campaign_id,
       i.d,
       i.impressions,
       ROUND(i.impressions * i.ctr * (0.8 + 0.4 * i.r3)),
       i.spend
FROM (
    SELECT b.campaign_id, b.d, b.spend, b.ctr, b.r3,
           ROUND(b.spend / b.cpm * 1000 * (0.9 + 0.2 * b.r2)) AS impressions
    FROM (
        SELECT c.campaign_id,
               dd.d,
               ch.benchmark_cpm * (0.85 + 0.30 * ((c.campaign_id * 53 % 100) / 100)) AS cpm,
               ch.benchmark_ctr * (0.60 + 0.80 * ((c.campaign_id * 37 % 100) / 100)) AS ctr,
               ((c.campaign_id * 31 + DATEDIFF(dd.d, '2026-01-01') * 17 + 53)  % 100) / 100 AS r1,
               ((c.campaign_id * 31 + DATEDIFF(dd.d, '2026-01-01') * 17 + 106) % 100) / 100 AS r2,
               ((c.campaign_id * 31 + DATEDIFF(dd.d, '2026-01-01') * 17 + 159) % 100) / 100 AS r3,
               ROUND(c.daily_budget
                     * (0.7 + 0.6 * (((c.campaign_id * 31 + DATEDIFF(dd.d, '2026-01-01') * 17 + 53) % 100) / 100))
                     * IF(WEEKDAY(dd.d) >= 5, 0.85, 1), 2) AS spend
        FROM campaigns c
        JOIN channels ch ON ch.channel_id = c.channel_id
        JOIN days dd     ON dd.d BETWEEN c.start_date AND LEAST(c.end_date, '2026-10-12')
        WHERE c.status <> 'Draft'
    ) b
) i;

-- ---------------------------------------------------------------------
-- CUSTOMERS
-- Part 1: 200 older customers (2024 to 2025), not tied to a campaign
-- ---------------------------------------------------------------------
INSERT INTO customers (customer_id, first_name, last_name, email, city, country, age_group, signup_date,
                       acquisition_channel_id, acquisition_campaign_id, email_opt_in)
WITH RECURSIVE nums AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 200
)
SELECT x.n,
       f.name,
       l.name,
       LOWER(CONCAT(f.name, '.', l.name, x.n, '@mail.example')),
       ELT(1 + (x.n % 10), 'Manila', 'Cebu City', 'Singapore', 'Sydney', 'Toronto',
                           'London', 'New York', 'Dubai', 'Kuala Lumpur', 'Davao City'),
       ELT(1 + (x.n % 10), 'Philippines', 'Philippines', 'Singapore', 'Australia', 'Canada',
                           'United Kingdom', 'United States', 'UAE', 'Malaysia', 'Philippines'),
       ELT(1 + ((x.n * 3) % 5), '18-24', '25-34', '35-44', '45-54', '55+'),
       DATE_ADD('2024-01-01', INTERVAL ((x.n * 7) % 730) DAY),
       IF(x.n % 2 = 0, 1, 8),
       NULL,
       IF(x.n % 4 = 0, 0, 1)
FROM nums x
JOIN name_pool_first f ON f.id = 1 + ((x.n * 7) % 40)
JOIN name_pool_last  l ON l.id = 1 + ((x.n * 11 + x.n DIV 40) % 40)
ORDER BY x.n;

-- Part 2: 1,300 new customers in 2026. Each one is credited to a campaign
-- that was running on the day they signed up. Campaigns with bigger daily
-- budgets and better channels win more customers.
INSERT INTO customers (customer_id, first_name, last_name, email, city, country, age_group, signup_date,
                       acquisition_channel_id, acquisition_campaign_id, email_opt_in)
WITH RECURSIVE nums AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 1300
),
base AS (
    SELECT n, DATE_ADD('2026-01-05', INTERVAL (n * 47) % 281 DAY) AS signup_date
    FROM nums
),
weighted AS (
    SELECT b.n, b.signup_date, c.campaign_id, c.channel_id,
           CAST(GREATEST(1, ROUND(c.daily_budget * ch.conversion_index)) AS SIGNED) AS wt
    FROM base b
    JOIN campaigns c ON b.signup_date BETWEEN c.start_date AND c.end_date AND c.status <> 'Draft'
    JOIN channels ch ON ch.channel_id = c.channel_id
),
running AS (
    SELECT w.*,
           CAST(SUM(w.wt) OVER (PARTITION BY w.n ORDER BY w.campaign_id) AS SIGNED) AS run_wt,
           CAST(SUM(w.wt) OVER (PARTITION BY w.n) AS SIGNED)                        AS total_wt
    FROM weighted w
)
SELECT r.n + 200,
       f.name,
       l.name,
       LOWER(CONCAT(f.name, '.', l.name, r.n + 200, '@mail.example')),
       ELT(1 + ((r.n + 200) % 10), 'Manila', 'Cebu City', 'Singapore', 'Sydney', 'Toronto',
                                   'London', 'New York', 'Dubai', 'Kuala Lumpur', 'Davao City'),
       ELT(1 + ((r.n + 200) % 10), 'Philippines', 'Philippines', 'Singapore', 'Australia', 'Canada',
                                   'United Kingdom', 'United States', 'UAE', 'Malaysia', 'Philippines'),
       ELT(1 + (((r.n + 200) * 3) % 5), '18-24', '25-34', '35-44', '45-54', '55+'),
       r.signup_date,
       r.channel_id,
       r.campaign_id,
       IF((r.n + 200) % 4 = 0, 0, 1)
FROM running r
JOIN name_pool_first f ON f.id = 1 + (((r.n + 200) * 7) % 40)
JOIN name_pool_last  l ON l.id = 1 + (((r.n + 200) * 11 + (r.n + 200) DIV 40) % 40)
WHERE (r.n * 7919) % r.total_wt >= r.run_wt - r.wt
  AND (r.n * 7919) % r.total_wt <  r.run_wt
ORDER BY r.n;

-- ---------------------------------------------------------------------
-- ORDERS (2,400 orders from January to 2026-10-12)
-- Some customers order many times, many order once, and some never
-- order, like a real store. About 1 in 5 orders is "Direct" (no campaign). The rest are credited
-- to a campaign that was running that day, using the same weighting.
-- Awareness campaigns are not credited with direct sales.
-- ---------------------------------------------------------------------
INSERT INTO orders (order_id, customer_id, order_date, campaign_id, status, discount_pct)
WITH RECURSIVE nums AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 2400
),
raw AS (
    SELECT x.n,
           c.customer_id,
           DATE_ADD(IF(c.signup_date < '2026-01-01', DATE('2026-01-01'), c.signup_date),
                    INTERVAL CRC32(CONCAT('d', x.n)) %
                      (DATEDIFF('2026-10-12',
                                IF(c.signup_date < '2026-01-01', DATE('2026-01-01'), c.signup_date)) + 1) DAY
           ) AS order_date
    FROM nums x
    JOIN customers c
      ON c.customer_id = 1 + FLOOR(1500 * POW(CRC32(CONCAT('c', x.n)) / 4294967296, 1.15))
),
weighted AS (
    SELECT r.n, r.customer_id, r.order_date, c.campaign_id,
           COALESCE(CAST(GREATEST(1, ROUND(c.daily_budget * ch.conversion_index)) AS SIGNED), 1) AS wt
    FROM raw r
    LEFT JOIN campaigns c ON r.order_date BETWEEN c.start_date AND c.end_date
                         AND c.status <> 'Draft'
                         AND c.objective IN ('Sales', 'Traffic', 'Leads')
    LEFT JOIN channels ch ON ch.channel_id = c.channel_id
),
running AS (
    SELECT w.*,
           CAST(SUM(w.wt) OVER (PARTITION BY w.n ORDER BY COALESCE(w.campaign_id, 0)) AS SIGNED) AS run_wt,
           CAST(SUM(w.wt) OVER (PARTITION BY w.n) AS SIGNED)                                      AS total_wt
    FROM weighted w
)
SELECT r.n,
       r.customer_id,
       r.order_date,
       IF(r.n % 5 = 0, NULL, r.campaign_id),
       CASE r.n % 25 WHEN 0 THEN 'Cancelled' WHEN 1 THEN 'Refunded' ELSE 'Completed' END,
       CASE r.n % 5  WHEN 0 THEN 10 WHEN 1 THEN 5 ELSE 0 END
FROM running r
WHERE (r.n * 7919) % r.total_wt >= r.run_wt - r.wt
  AND (r.n * 7919) % r.total_wt <  r.run_wt
ORDER BY r.n;

-- ORDER ITEMS: each order gets 1 to 3 products
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
WITH RECURSIVE k AS (
    SELECT 1 AS k
    UNION ALL
    SELECT k + 1 FROM k WHERE k < 3
)
SELECT o.order_id,
       p.product_id,
       1 + ((o.order_id + k.k) % 3),
       p.price
FROM orders o
CROSS JOIN k
JOIN products p ON p.product_id = 1 + ((o.order_id * k.k * 13 + k.k * 5) % 20)
WHERE k.k <= 1 + ((o.order_id * 7) % 3);

-- ---------------------------------------------------------------------
-- LEADS: generated from clicks on Leads and Traffic campaigns
-- (5 percent of clicks become leads on Leads campaigns, 1.5 percent on
-- Traffic campaigns). Each lead is at a funnel stage.
-- ---------------------------------------------------------------------
INSERT INTO leads (campaign_id, lead_date, stage)
WITH RECURSIVE nums AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 200
)
SELECT s.campaign_id,
       s.spend_date,
       CASE
           WHEN ((s.campaign_id * 97 + DATEDIFF(s.spend_date, '2026-01-01') * 13 + nums.n * 7) % 20) < 9  THEN 'Lead'
           WHEN ((s.campaign_id * 97 + DATEDIFF(s.spend_date, '2026-01-01') * 13 + nums.n * 7) % 20) < 13 THEN 'MQL'
           WHEN ((s.campaign_id * 97 + DATEDIFF(s.spend_date, '2026-01-01') * 13 + nums.n * 7) % 20) < 15 THEN 'SQL'
           WHEN ((s.campaign_id * 97 + DATEDIFF(s.spend_date, '2026-01-01') * 13 + nums.n * 7) % 20) < 17 THEN 'Customer'
           ELSE 'Lost'
       END
FROM ad_spend_daily s
JOIN campaigns c ON c.campaign_id = s.campaign_id AND c.objective IN ('Leads', 'Traffic')
JOIN nums        ON nums.n <= ROUND(s.clicks * IF(c.objective = 'Leads', 0.05, 0.015));

-- ---------------------------------------------------------------------
-- SOCIAL POSTS: one post every 3 days on each social campaign
-- ---------------------------------------------------------------------
INSERT INTO social_posts (campaign_id, channel_id, post_date, content_type, reach, likes, comments, shares, link_clicks)
SELECT g.campaign_id,
       g.channel_id,
       g.post_date,
       ELT(g.t, 'Image', 'Video', 'Carousel', 'Story', 'Reel', 'Text'),
       g.reach,
       ROUND(g.reach * g.eng * 0.80),
       ROUND(g.reach * g.eng * 0.08),
       ROUND(g.reach * g.eng * 0.12),
       ROUND(g.reach * 0.004 * (1 + g.t % 3))
FROM (
    SELECT s.campaign_id,
           c.channel_id,
           s.spend_date AS post_date,
           1 + ((s.campaign_id + DATEDIFF(s.spend_date, '2026-01-01')) % 6) AS t,
           ROUND(s.impressions * 0.6) AS reach,
           ELT(1 + ((s.campaign_id + DATEDIFF(s.spend_date, '2026-01-01')) % 6),
               0.020, 0.045, 0.030, 0.015, 0.055, 0.010) AS eng
    FROM ad_spend_daily s
    JOIN campaigns c ON c.campaign_id = s.campaign_id
    WHERE c.channel_id IN (2, 3, 5, 6, 7)
      AND DATEDIFF(s.spend_date, '2026-01-01') % 3 = 0
) g;

-- A/B TESTS
INSERT INTO ab_tests (test_name, campaign_id, variant, visitors, conversions) VALUES
    ('Email subject: discount vs curiosity', 8,  'A', 12000, 396),
    ('Email subject: discount vs curiosity', 8,  'B', 12000, 468),
    ('Email subject: emoji vs no emoji',     16, 'A',  9000, 270),
    ('Email subject: emoji vs no emoji',     16, 'B',  9000, 279),
    ('Landing page headline',                14, 'A',  4000, 160),
    ('Landing page headline',                14, 'B',  4000, 212),
    ('Search ad copy: price vs benefit',     10, 'A',  7500, 225),
    ('Search ad copy: price vs benefit',     10, 'B',  7500, 240),
    ('Video hook: first 3 seconds',          17, 'A', 15000, 300),
    ('Video hook: first 3 seconds',          17, 'B', 15000, 390),
    ('Checkout button color',                19, 'A',  6000, 210),
    ('Checkout button color',                19, 'B',  6000, 192);

-- MONTHLY TARGETS (January to October 2026)
INSERT INTO monthly_targets (target_month, revenue_target, new_customer_target) VALUES
    ('2026-01-01',   8000.00, 130),
    ('2026-02-01',  10000.00, 130),
    ('2026-03-01',  16000.00, 140),
    ('2026-04-01',  22000.00, 140),
    ('2026-05-01',  30000.00, 140),
    ('2026-06-01',  30000.00, 140),
    ('2026-07-01',  45000.00, 140),
    ('2026-08-01',  52000.00, 140),
    ('2026-09-01',  80000.00, 140),
    ('2026-10-01', 100000.00, 130);   -- October is only 12 days old in this project

-- =====================================================================
-- VIEWS (saved queries you can use like tables)
-- =====================================================================

-- One row per order with its total (gross and after discount)
CREATE VIEW v_order_totals AS
SELECT o.order_id,
       o.customer_id,
       o.order_date,
       o.campaign_id,
       o.status,
       o.discount_pct,
       ROUND(SUM(oi.quantity * oi.unit_price), 2)                                 AS gross_amount,
       ROUND(SUM(oi.quantity * oi.unit_price) * (1 - o.discount_pct / 100), 2)    AS net_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date, o.campaign_id, o.status, o.discount_pct;

-- One row per campaign with all the main marketing numbers
--   CTR  = clicks / impressions        CPC = spend / clicks
--   CPM  = cost per 1,000 impressions  ROAS = revenue / spend
--   CAC  = spend / new customers
CREATE VIEW v_campaign_performance AS
SELECT c.campaign_id,
       c.campaign_name,
       ch.channel_name,
       c.objective,
       c.budget,
       COALESCE(s.spend, 0)                                  AS spend,
       COALESCE(s.impressions, 0)                            AS impressions,
       COALESCE(s.clicks, 0)                                 AS clicks,
       ROUND(100 * s.clicks / NULLIF(s.impressions, 0), 2)   AS ctr_pct,
       ROUND(s.spend / NULLIF(s.clicks, 0), 2)               AS cpc,
       ROUND(1000 * s.spend / NULLIF(s.impressions, 0), 2)   AS cpm,
       COALESCE(o.orders, 0)                                 AS orders,
       COALESCE(o.revenue, 0)                                AS revenue,
       ROUND(o.revenue / NULLIF(s.spend, 0), 2)              AS roas,
       COALESCE(cu.new_customers, 0)                         AS new_customers,
       ROUND(s.spend / NULLIF(cu.new_customers, 0), 2)       AS cac
FROM campaigns c
JOIN channels ch ON ch.channel_id = c.channel_id
LEFT JOIN (SELECT campaign_id,
                  SUM(spend) AS spend, SUM(impressions) AS impressions, SUM(clicks) AS clicks
           FROM ad_spend_daily
           GROUP BY campaign_id) s ON s.campaign_id = c.campaign_id
LEFT JOIN (SELECT campaign_id,
                  COUNT(*) AS orders, ROUND(SUM(net_revenue), 2) AS revenue
           FROM v_order_totals
           WHERE status = 'Completed' AND campaign_id IS NOT NULL
           GROUP BY campaign_id) o ON o.campaign_id = c.campaign_id
LEFT JOIN (SELECT acquisition_campaign_id AS campaign_id, COUNT(*) AS new_customers
           FROM customers
           WHERE acquisition_campaign_id IS NOT NULL
           GROUP BY acquisition_campaign_id) cu ON cu.campaign_id = c.campaign_id;

-- One row per customer with their order history (completed orders only)
CREATE VIEW v_customer_summary AS
SELECT cu.customer_id,
       CONCAT(cu.first_name, ' ', cu.last_name)  AS customer,
       cu.city,
       cu.country,
       cu.age_group,
       cu.signup_date,
       cu.acquisition_channel_id,
       COUNT(ot.order_id)                        AS orders,
       COALESCE(SUM(ot.net_revenue), 0)          AS revenue,
       MIN(ot.order_date)                        AS first_order,
       MAX(ot.order_date)                        AS last_order,
       ROUND(AVG(ot.net_revenue), 2)             AS avg_order_value
FROM customers cu
LEFT JOIN v_order_totals ot ON ot.customer_id = cu.customer_id AND ot.status = 'Completed'
GROUP BY cu.customer_id, cu.first_name, cu.last_name, cu.city, cu.country,
         cu.age_group, cu.signup_date, cu.acquisition_channel_id;

-- =====================================================================
-- STORED PROCEDURE: a full report for ONE campaign
-- Usage:  CALL sp_campaign_report(4);
-- =====================================================================
DELIMITER //

CREATE PROCEDURE sp_campaign_report(IN p_campaign_id INT)
BEGIN
    -- Part 1: the campaign's overall numbers
    SELECT * FROM v_campaign_performance WHERE campaign_id = p_campaign_id;

    -- Part 2: week by week spend and clicks
    SELECT YEARWEEK(spend_date, 1)                    AS year_week,
           MIN(spend_date)                            AS week_start,
           ROUND(SUM(spend), 2)                       AS spend,
           SUM(impressions)                           AS impressions,
           SUM(clicks)                                AS clicks,
           ROUND(100 * SUM(clicks) / SUM(impressions), 2) AS ctr_pct
    FROM ad_spend_daily
    WHERE campaign_id = p_campaign_id
    GROUP BY YEARWEEK(spend_date, 1)
    ORDER BY year_week;
END //

DELIMITER ;

-- =====================================================================
-- INDEXES (make big queries faster)
-- =====================================================================
CREATE INDEX idx_orders_date      ON orders (order_date);
CREATE INDEX idx_orders_customer  ON orders (customer_id, order_date);
CREATE INDEX idx_spend_date       ON ad_spend_daily (spend_date);
CREATE INDEX idx_customers_email  ON customers (email);
CREATE INDEX idx_customers_signup ON customers (signup_date);
CREATE INDEX idx_leads_campaign   ON leads (campaign_id, stage);

-- Remove the helper name lists
DROP TABLE name_pool_first;
DROP TABLE name_pool_last;

-- =====================================================================
-- DONE. How many rows were created in each table?
-- =====================================================================
SELECT 'channels' AS table_name, COUNT(*) AS row_count FROM channels
UNION ALL SELECT 'campaigns',       COUNT(*) FROM campaigns
UNION ALL SELECT 'ad_spend_daily',  COUNT(*) FROM ad_spend_daily
UNION ALL SELECT 'customers',       COUNT(*) FROM customers
UNION ALL SELECT 'products',        COUNT(*) FROM products
UNION ALL SELECT 'orders',          COUNT(*) FROM orders
UNION ALL SELECT 'order_items',     COUNT(*) FROM order_items
UNION ALL SELECT 'leads',           COUNT(*) FROM leads
UNION ALL SELECT 'social_posts',    COUNT(*) FROM social_posts
UNION ALL SELECT 'ab_tests',        COUNT(*) FROM ab_tests
UNION ALL SELECT 'monthly_targets', COUNT(*) FROM monthly_targets;
