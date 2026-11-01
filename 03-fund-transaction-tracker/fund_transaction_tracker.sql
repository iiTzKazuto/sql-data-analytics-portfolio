-- =====================================================================
-- FUND AND TRANSACTION TRACKER  (MySQL 8.0)
-- ---------------------------------------------------------------------
-- WHAT THIS PROJECT IS
--   A small investment platform database. Clients own accounts, accounts
--   buy and sell units of funds, and every trade is a row in the
--   transactions table. The sample data includes a few deliberate
--   mistakes (duplicates, wrong amounts, oversold positions, trades in
--   closed funds) so you can practice finding errors with SQL, which is
--   what data reconciliation and quality assurance work is about.
--
-- HOW TO RUN THIS FILE IN MYSQL WORKBENCH
--   1. File > Open SQL Script...  and choose this file.
--   2. Press Ctrl+Shift+Enter  (runs the WHOLE script, top to bottom).
--      Do NOT use plain Ctrl+Enter, that only runs one statement.
--   3. In the Schemas panel, right-click and choose "Refresh All".
--      You will see a new database: fund_tracker.
--   4. Scroll to the CHECKS section near the bottom. Click inside ONE
--      query and press Ctrl+Enter to run just that one.
--
-- NOTE: This creates a NEW database called fund_tracker, so your other
-- databases are untouched. Running the script again deletes fund_tracker
-- and rebuilds it from scratch.
-- =====================================================================

DROP DATABASE IF EXISTS fund_tracker;
CREATE DATABASE fund_tracker;
USE fund_tracker;

-- ---------------------------------------------------------------------
-- 1. ADVISORS
-- ---------------------------------------------------------------------
CREATE TABLE advisors (
    advisor_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50)  NOT NULL,
    last_name  VARCHAR(50)  NOT NULL,
    email      VARCHAR(100) UNIQUE
);

-- ---------------------------------------------------------------------
-- 2. CLIENTS
-- ---------------------------------------------------------------------
CREATE TABLE clients (
    client_id    INT AUTO_INCREMENT PRIMARY KEY,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    email        VARCHAR(100) UNIQUE,
    country      VARCHAR(50),
    risk_profile ENUM('Conservative', 'Moderate', 'Aggressive') NOT NULL,
    advisor_id   INT,
    join_date    DATE NOT NULL,
    FOREIGN KEY (advisor_id) REFERENCES advisors(advisor_id)
);

-- ---------------------------------------------------------------------
-- 3. FUNDS (the "fund setup" table)
--    status shows whether a fund is ready to trade:
--      Active        = open for trading
--      Pending Setup = not ready yet, should have NO trades
--      Closed        = no new trades after closed_date
-- ---------------------------------------------------------------------
CREATE TABLE funds (
    fund_id        INT AUTO_INCREMENT PRIMARY KEY,
    fund_code      VARCHAR(10)  NOT NULL UNIQUE,
    fund_name      VARCHAR(100) NOT NULL,
    fund_type      ENUM('Equity', 'Bond', 'Balanced', 'Income', 'Money Market') NOT NULL,
    currency       CHAR(3) NOT NULL DEFAULT 'USD',
    risk_level     ENUM('Low', 'Moderate', 'High') NOT NULL,
    expense_ratio  DECIMAL(4,2) NOT NULL,      -- percent per year
    initial_nav    DECIMAL(8,2) NOT NULL,      -- starting price per unit
    inception_date DATE NOT NULL,
    status         ENUM('Active', 'Pending Setup', 'Closed') NOT NULL,
    closed_date    DATE
);

-- ---------------------------------------------------------------------
-- 4. FUND_PRICES (month-end price per unit, called NAV)
-- ---------------------------------------------------------------------
CREATE TABLE fund_prices (
    fund_id    INT NOT NULL,
    price_date DATE NOT NULL,
    nav        DECIMAL(10,2) NOT NULL CHECK (nav > 0),
    PRIMARY KEY (fund_id, price_date),
    FOREIGN KEY (fund_id) REFERENCES funds(fund_id)
);

-- ---------------------------------------------------------------------
-- 5. ACCOUNTS (a client can have more than one)
-- ---------------------------------------------------------------------
CREATE TABLE accounts (
    account_id   INT AUTO_INCREMENT PRIMARY KEY,
    client_id    INT NOT NULL,
    account_type ENUM('Individual', 'Joint', 'Retirement') NOT NULL,
    open_date    DATE NOT NULL,
    status       ENUM('Active', 'Closed') NOT NULL DEFAULT 'Active',
    close_date   DATE,
    FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

-- ---------------------------------------------------------------------
-- 6. TRANSACTIONS
--    BUY / SELL   : units and price are filled in, amount = units x price
--    DIVIDEND/FEE : units and price are empty, only amount is filled in
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id   INT AUTO_INCREMENT PRIMARY KEY,
    account_id       INT NOT NULL,
    fund_id          INT NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_type ENUM('BUY', 'SELL', 'DIVIDEND', 'FEE') NOT NULL,
    units            DECIMAL(14,4),
    price            DECIMAL(10,2),
    amount           DECIMAL(14,2) NOT NULL CHECK (amount > 0),
    status           ENUM('Settled', 'Pending', 'Failed') NOT NULL DEFAULT 'Settled',
    FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    FOREIGN KEY (fund_id)    REFERENCES funds(fund_id)
);

-- =====================================================================
-- SAMPLE DATA
-- =====================================================================

INSERT INTO advisors (first_name, last_name, email) VALUES
    ('Jonathan', 'Hayes',   'jonathan.hayes@advisors.example'),
    ('Maria',    'Santos',  'maria.santos@advisors.example'),
    ('David',    'Okoye',   'david.okoye@advisors.example'),
    ('Elena',    'Petrova', 'elena.petrova@advisors.example');

INSERT INTO clients (first_name, last_name, email, country, risk_profile, advisor_id, join_date) VALUES
    ('Oliver',    'Bennett',   'oliver.bennett@mail.example',   'United Kingdom', 'Moderate',     1, '2022-03-14'),
    ('Sophia',    'Martinez',  'sophia.martinez@mail.example',  'United States',  'Aggressive',   2, '2022-05-02'),
    ('Liam',      'Foster',    'liam.foster@mail.example',      'Canada',         'Conservative', 3, '2022-07-19'),
    ('Emma',      'Wilson',    'emma.wilson@mail.example',      'Australia',      'Moderate',     4, '2022-09-08'),
    ('Noah',      'Tan',       'noah.tan@mail.example',         'Singapore',      'Aggressive',   1, '2022-11-21'),
    ('Ava',       'Robinson',  'ava.robinson@mail.example',     'United States',  'Conservative', 2, '2023-01-10'),
    ('William',   'Clarke',    'william.clarke@mail.example',   'United Kingdom', 'Moderate',     3, '2023-02-27'),
    ('Isabella',  'Costa',     'isabella.costa@mail.example',   'Canada',         'Moderate',     4, '2023-03-15'),
    ('James',     'Nguyen',    'james.nguyen@mail.example',     'Australia',      'Aggressive',   1, '2023-04-03'),
    ('Mia',       'Patel',     'mia.patel@mail.example',        'Singapore',      'Conservative', 2, '2023-05-22'),
    ('Benjamin',  'Hughes',    'benjamin.hughes@mail.example',  'United States',  'Moderate',     3, '2023-06-12'),
    ('Charlotte', 'Lim',       'charlotte.lim@mail.example',    'Singapore',      'Moderate',     4, '2023-07-31'),
    ('Lucas',     'Meyer',     'lucas.meyer@mail.example',      'Canada',         'Aggressive',   1, '2023-08-18'),
    ('Amelia',    'Brooks',    'amelia.brooks@mail.example',    'United Kingdom', 'Conservative', 2, '2023-09-05'),
    ('Henry',     'Walker',    'henry.walker@mail.example',     'Australia',      'Moderate',     3, '2023-10-23'),
    ('Harper',    'Jenkins',   'harper.jenkins@mail.example',   'United States',  'Aggressive',   4, '2023-11-14'),
    ('Alexander', 'Wong',      'alexander.wong@mail.example',   'Singapore',      'Moderate',     1, '2024-01-08'),
    ('Evelyn',    'Scott',     'evelyn.scott@mail.example',     'Canada',         'Conservative', 2, '2024-02-19'),
    ('Daniel',    'Ortiz',     'daniel.ortiz@mail.example',     'United States',  'Moderate',     3, '2024-03-11'),
    ('Abigail',   'Turner',    'abigail.turner@mail.example',   'United Kingdom', 'Aggressive',   4, '2024-04-29'),
    ('Matthew',   'Reid',      'matthew.reid@mail.example',     'Australia',      'Conservative', 1, '2024-05-16'),
    ('Ella',      'Fraser',    'ella.fraser@mail.example',      'Canada',         'Moderate',     2, '2024-06-24'),
    ('Joseph',    'Adams',     'joseph.adams@mail.example',     'United States',  'Aggressive',   3, '2024-07-08'),
    ('Scarlett',  'Chua',      'scarlett.chua@mail.example',    'Singapore',      'Moderate',     4, '2024-08-26'),
    ('David',     'Murphy',    'david.murphy@mail.example',     'United Kingdom', 'Conservative', 1, '2024-09-30'),
    ('Grace',     'Sullivan',  'grace.sullivan@mail.example',   'Australia',      'Moderate',     2, '2024-10-21'),
    ('Samuel',    'Cooper',    'samuel.cooper@mail.example',    'Canada',         'Aggressive',   3, '2025-01-13'),
    ('Victoria',  'Hayes',     'victoria.hayes@mail.example',   'United States',  'Moderate',     4, '2025-02-24'),
    ('Andrew',    'Kowalski',  'andrew.kowalski@mail.example',  'United Kingdom', 'Conservative', 1, '2025-04-07'),
    ('Lily',      'Santos',    'lily.santos@mail.example',      'Singapore',      'Moderate',     2, '2025-06-02');

INSERT INTO funds
    (fund_id, fund_code, fund_name, fund_type, currency, risk_level, expense_ratio, initial_nav, inception_date, status, closed_date)
VALUES
    (1, 'GBF-001', 'Global Balanced Fund',        'Balanced',     'USD', 'Moderate', 0.85, 25.00, '2015-04-01', 'Active',        NULL),
    (2, 'USE-002', 'US Equity Growth Fund',       'Equity',       'USD', 'High',     1.05, 42.50, '2012-09-17', 'Active',        NULL),
    (3, 'ABF-003', 'Aggregate Bond Fund',         'Bond',         'USD', 'Low',      0.45, 10.20, '2010-02-08', 'Active',        NULL),
    (4, 'EMF-004', 'Emerging Markets Fund',       'Equity',       'USD', 'High',     1.25, 18.75, '2016-06-20', 'Active',        NULL),
    (5, 'MMF-005', 'Money Market Fund',           'Money Market', 'USD', 'Low',      0.20,  1.00, '2008-01-14', 'Active',        NULL),
    (6, 'INF-006', 'Global Income Fund',          'Income',       'USD', 'Low',      0.65, 12.40, '2018-03-05', 'Active',        NULL),
    (7, 'TEC-007', 'Technology Leaders Fund',     'Equity',       'USD', 'High',     1.15, 55.00, '2019-10-28', 'Active',        NULL),
    (8, 'ESG-008', 'Sustainable Future Fund',     'Equity',       'USD', 'Moderate', 0.95, 21.30, '2026-10-01', 'Pending Setup', NULL),
    (9, 'REF-009', 'Real Estate Income Fund',     'Income',       'USD', 'Moderate', 0.90, 15.60, '2017-05-15', 'Closed',        '2026-06-30');

-- Accounts 1 to 30: one account per client, opened on the day they joined
INSERT INTO accounts (client_id, account_type, open_date)
SELECT client_id,
       CASE client_id % 3 WHEN 0 THEN 'Joint' WHEN 1 THEN 'Individual' ELSE 'Retirement' END,
       join_date
FROM clients
ORDER BY client_id;

-- Accounts 31 to 33: second accounts for clients 1, 2 and 3 (used for the test cases)
INSERT INTO accounts (account_id, client_id, account_type, open_date, status, close_date) VALUES
    (31, 1, 'Individual', '2025-06-01', 'Active', NULL),
    (32, 2, 'Individual', '2025-06-01', 'Active', NULL),
    (33, 3, 'Individual', '2024-01-15', 'Closed', '2026-08-31');

-- Month-end prices from January to September 2026 (skips the fund that is not set up yet)
INSERT INTO fund_prices (fund_id, price_date, nav)
WITH RECURSIVE months AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM months WHERE n < 9
)
SELECT f.fund_id,
       LAST_DAY(DATE_ADD('2026-01-01', INTERVAL m.n - 1 MONTH)),
       ROUND(f.initial_nav * (1 + 0.01 * m.n) + ((f.fund_id * m.n) % 5) * 0.02, 2)
FROM funds f
CROSS JOIN months m
WHERE f.status <> 'Pending Setup';

-- BUY transactions: each of the first 30 accounts makes 3 purchases
INSERT INTO transactions (account_id, fund_id, transaction_date, transaction_type, units, price, amount, status)
SELECT g.account_id, g.fund_id, g.txn_date, 'BUY', g.units, g.price, ROUND(g.units * g.price, 2), 'Settled'
FROM (
    SELECT a.account_id,
           f.fund_id,
           DATE_ADD('2026-01-05', INTERVAL (a.account_id % 20 + s.step * 30) DAY) AS txn_date,
           ROUND((250 * (1 + a.account_id % 6)) / f.initial_nav, 4)               AS units,
           f.initial_nav                                                          AS price
    FROM accounts a
    CROSS JOIN (SELECT 1 AS step UNION ALL SELECT 2 UNION ALL SELECT 3) s
    JOIN funds f ON f.fund_id = 1 + ((a.account_id + s.step * 3) % 7)
    WHERE a.account_id <= 30
) g;

-- SELL transactions: every 4th account sells half of its first purchase
INSERT INTO transactions (account_id, fund_id, transaction_date, transaction_type, units, price, amount, status)
SELECT x.account_id,
       x.fund_id,
       DATE_ADD(x.transaction_date, INTERVAL 45 DAY),
       'SELL',
       ROUND(x.units / 2, 4),
       ROUND(x.price * 1.05, 2),
       ROUND(ROUND(x.units / 2, 4) * ROUND(x.price * 1.05, 2), 2),
       'Settled'
FROM (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY t.account_id ORDER BY t.transaction_id) AS rn
    FROM transactions t
    WHERE t.transaction_type = 'BUY'
) x
WHERE x.rn = 1 AND x.account_id % 4 = 0;

-- DIVIDEND transactions: bond and income fund purchases pay 1 percent after 60 days
INSERT INTO transactions (account_id, fund_id, transaction_date, transaction_type, units, price, amount, status)
SELECT t.account_id,
       t.fund_id,
       DATE_ADD(t.transaction_date, INTERVAL 60 DAY),
       'DIVIDEND',
       NULL,
       NULL,
       ROUND(t.amount * 0.01, 2),
       'Settled'
FROM transactions t
JOIN funds f ON f.fund_id = t.fund_id
WHERE t.transaction_type = 'BUY'
  AND f.fund_type IN ('Bond', 'Income');

-- Recent transactions, including DELIBERATE MISTAKES for you to find later
INSERT INTO transactions (account_id, fund_id, transaction_date, transaction_type, units, price, amount, status) VALUES
    -- normal purchase
    (32, 2, '2026-10-01', 'BUY',  100.0000, 42.50, 4250.00, 'Settled'),
    -- MISTAKE: sells 150 units but only owns 100 (oversold)
    (32, 2, '2026-10-08', 'SELL', 150.0000, 44.00, 6600.00, 'Settled'),
    -- MISTAKE: the same purchase entered twice (duplicate)
    (32, 3, '2026-10-02', 'BUY',  200.0000, 10.20, 2040.00, 'Settled'),
    (32, 3, '2026-10-02', 'BUY',  200.0000, 10.20, 2040.00, 'Settled'),
    -- MISTAKE: 100 units x 25.00 should be 2500.00, not 2600.00
    (32, 1, '2026-10-03', 'BUY',  100.0000, 25.00, 2600.00, 'Settled'),
    -- MISTAKE: still Pending after more than 3 weeks
    (31, 1, '2026-09-20', 'BUY',   50.0000, 25.00, 1250.00, 'Pending'),
    -- a failed trade that needs follow up
    (31, 5, '2026-10-09', 'BUY', 1000.0000,  1.00, 1000.00, 'Failed'),
    -- MISTAKE: trade in a fund that is still Pending Setup
    (31, 8, '2026-10-05', 'BUY',   40.0000, 21.30,  852.00, 'Settled'),
    -- MISTAKE: purchase in a fund that closed on 2026-06-30
    (31, 9, '2026-09-15', 'BUY',   60.0000, 15.60,  936.00, 'Settled'),
    -- MISTAKE: purchase in an account that was closed on 2026-08-31
    (33, 1, '2026-09-10', 'BUY',   80.0000, 25.00, 2000.00, 'Settled');

-- =====================================================================
-- VIEWS (saved queries you can use like tables)
-- =====================================================================

-- Latest price for each fund
CREATE VIEW v_latest_nav AS
SELECT fp.fund_id, fp.price_date, fp.nav
FROM fund_prices fp
JOIN (SELECT fund_id, MAX(price_date) AS last_date
      FROM fund_prices
      GROUP BY fund_id) m
  ON m.fund_id = fp.fund_id AND m.last_date = fp.price_date;

-- Units held by each account in each fund (settled trades only)
CREATE VIEW v_holdings AS
SELECT t.account_id,
       t.fund_id,
       SUM(CASE t.transaction_type
               WHEN 'BUY'  THEN  t.units
               WHEN 'SELL' THEN -t.units
               ELSE 0
           END) AS units_held
FROM transactions t
WHERE t.status = 'Settled'
GROUP BY t.account_id, t.fund_id;

-- Quick check: how many rows were created in each table?
SELECT 'advisors' AS table_name, COUNT(*) AS row_count FROM advisors
UNION ALL SELECT 'clients',      COUNT(*) FROM clients
UNION ALL SELECT 'funds',        COUNT(*) FROM funds
UNION ALL SELECT 'fund_prices',  COUNT(*) FROM fund_prices
UNION ALL SELECT 'accounts',     COUNT(*) FROM accounts
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions;

-- =====================================================================
-- REPORTS
-- Click inside ONE query and press Ctrl+Enter to run just that one.
-- =====================================================================

-- 1) Every account with its client and advisor
SELECT  a.account_id,
        CONCAT(c.first_name, ' ', c.last_name) AS client,
        a.account_type,
        a.status,
        CONCAT(ad.first_name, ' ', ad.last_name) AS advisor
FROM accounts a
JOIN clients c      ON a.client_id  = c.client_id
LEFT JOIN advisors ad ON c.advisor_id = ad.advisor_id
ORDER BY a.account_id;

-- 2) What does each account own right now, and what is it worth?
SELECT  h.account_id,
        f.fund_code,
        f.fund_name,
        ROUND(h.units_held, 4)               AS units_held,
        n.nav                                AS latest_price,
        ROUND(h.units_held * n.nav, 2)       AS market_value
FROM v_holdings h
JOIN funds f        ON f.fund_id = h.fund_id
JOIN v_latest_nav n ON n.fund_id = h.fund_id
WHERE h.units_held > 0
ORDER BY h.account_id, f.fund_code;

-- 3) Total portfolio value per client (largest first)
SELECT  CONCAT(c.first_name, ' ', c.last_name) AS client,
        ROUND(SUM(h.units_held * n.nav), 2)    AS portfolio_value
FROM v_holdings h
JOIN accounts a     ON a.account_id = h.account_id
JOIN clients c      ON c.client_id  = a.client_id
JOIN v_latest_nav n ON n.fund_id    = h.fund_id
WHERE h.units_held > 0
GROUP BY c.client_id, c.first_name, c.last_name
ORDER BY portfolio_value DESC
LIMIT 10;

-- 4) Total money invested in each fund (assets under management)
SELECT  f.fund_code,
        f.fund_name,
        ROUND(SUM(h.units_held * n.nav), 2) AS total_assets
FROM v_holdings h
JOIN funds f        ON f.fund_id = h.fund_id
JOIN v_latest_nav n ON n.fund_id = h.fund_id
WHERE h.units_held > 0
GROUP BY f.fund_id, f.fund_code, f.fund_name
ORDER BY total_assets DESC;

-- 5) Number of trades and money moved per month
SELECT  DATE_FORMAT(transaction_date, '%Y-%m') AS month,
        COUNT(*)                               AS trades,
        SUM(amount)                            AS total_amount
FROM transactions
WHERE transaction_type IN ('BUY', 'SELL')
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY month;

-- 6) Total invested per advisor (their "book of business")
SELECT  CONCAT(ad.first_name, ' ', ad.last_name) AS advisor,
        COUNT(DISTINCT c.client_id)              AS clients,
        ROUND(SUM(h.units_held * n.nav), 2)      AS client_assets
FROM advisors ad
JOIN clients c      ON c.advisor_id = ad.advisor_id
JOIN accounts a     ON a.client_id  = c.client_id
JOIN v_holdings h   ON h.account_id = a.account_id
JOIN v_latest_nav n ON n.fund_id    = h.fund_id
WHERE h.units_held > 0
GROUP BY ad.advisor_id, ad.first_name, ad.last_name
ORDER BY client_assets DESC;

-- =====================================================================
-- CHECKS: FIND THE MISTAKES (data reconciliation and quality assurance)
-- Each check should return the planted mistake. A clean database
-- would return no rows for any of them.
-- =====================================================================

-- CHECK 1) Duplicate transactions (same account, fund, date, type, units, amount)
SELECT  account_id, fund_id, transaction_date, transaction_type, units, amount,
        COUNT(*) AS times_entered
FROM transactions
GROUP BY account_id, fund_id, transaction_date, transaction_type, units, amount
HAVING COUNT(*) > 1;

-- CHECK 2) Amount does not equal units x price (allowing 1 cent for rounding)
SELECT  transaction_id, account_id, fund_id, units, price,
        amount                       AS recorded_amount,
        ROUND(units * price, 2)      AS correct_amount,
        ROUND(amount - units * price, 2) AS difference
FROM transactions
WHERE transaction_type IN ('BUY', 'SELL')
  AND ABS(amount - units * price) > 0.01;

-- CHECK 3) Negative holdings (sold more than owned)
SELECT  h.account_id, f.fund_code, ROUND(h.units_held, 4) AS units_held
FROM v_holdings h
JOIN funds f ON f.fund_id = h.fund_id
WHERE h.units_held < 0;

-- CHECK 4) Transactions stuck in Pending for more than 5 days
--          (uses a fixed "today" of 2026-10-12 so results stay the same)
SELECT  transaction_id, account_id, fund_id, transaction_date, amount,
        DATEDIFF('2026-10-12', transaction_date) AS days_pending
FROM transactions
WHERE status = 'Pending'
  AND DATEDIFF('2026-10-12', transaction_date) > 5;

-- CHECK 5) Failed transactions that need follow up
SELECT  transaction_id, account_id, fund_id, transaction_date, amount
FROM transactions
WHERE status = 'Failed';

-- CHECK 6) Trades in funds that were not open for trading
--          (still Pending Setup, or traded after the fund closed)
SELECT  t.transaction_id, t.account_id, f.fund_code, f.status AS fund_status,
        f.closed_date, t.transaction_date, t.transaction_type, t.amount
FROM transactions t
JOIN funds f ON f.fund_id = t.fund_id
WHERE t.transaction_type IN ('BUY', 'SELL')
  AND (   f.status = 'Pending Setup'
       OR (f.closed_date IS NOT NULL AND t.transaction_date > f.closed_date));

-- CHECK 7) Transactions in accounts after the account was closed
SELECT  t.transaction_id, t.account_id, a.close_date, t.transaction_date, t.amount
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
WHERE a.close_date IS NOT NULL
  AND t.transaction_date > a.close_date;

-- CHECK 8) Funds that have no price loaded (fund setup is incomplete)
SELECT  f.fund_id, f.fund_code, f.fund_name, f.status
FROM funds f
LEFT JOIN fund_prices fp ON fp.fund_id = f.fund_id
WHERE fp.fund_id IS NULL;

-- CHECK 9) Transactions dated before the account was opened
SELECT  t.transaction_id, t.account_id, a.open_date, t.transaction_date
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
WHERE t.transaction_date < a.open_date;

-- CHECK 10) One summary of every problem found
SELECT 'Duplicate transactions' AS issue, COUNT(*) AS rows_found FROM (
    SELECT 1 FROM transactions
    GROUP BY account_id, fund_id, transaction_date, transaction_type, units, amount
    HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'Wrong amount (units x price)', COUNT(*) FROM transactions
WHERE transaction_type IN ('BUY', 'SELL') AND ABS(amount - units * price) > 0.01
UNION ALL
SELECT 'Negative holdings', COUNT(*) FROM v_holdings WHERE units_held < 0
UNION ALL
SELECT 'Stuck pending (over 5 days)', COUNT(*) FROM transactions
WHERE status = 'Pending' AND DATEDIFF('2026-10-12', transaction_date) > 5
UNION ALL
SELECT 'Failed transactions', COUNT(*) FROM transactions WHERE status = 'Failed'
UNION ALL
SELECT 'Trades in unavailable funds', COUNT(*) FROM transactions t
JOIN funds f ON f.fund_id = t.fund_id
WHERE t.transaction_type IN ('BUY', 'SELL')
  AND (f.status = 'Pending Setup'
       OR (f.closed_date IS NOT NULL AND t.transaction_date > f.closed_date))
UNION ALL
SELECT 'Trades after account closed', COUNT(*) FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
WHERE a.close_date IS NOT NULL AND t.transaction_date > a.close_date;

-- =====================================================================
-- FIX EXAMPLES
-- Commented out so they don't run by accident. To try one, remove the
-- "-- " at the start of its lines and run it. Run the CHECK again after
-- to prove the problem is gone.
-- =====================================================================

-- Fix the wrong amount:
-- UPDATE transactions
-- SET amount = ROUND(units * price, 2)
-- WHERE transaction_type IN ('BUY', 'SELL')
--   AND ABS(amount - units * price) > 0.01;

-- Remove one copy of the duplicate (keeps the one with the lowest id):
-- DELETE t1 FROM transactions t1
-- JOIN transactions t2
--   ON  t1.account_id = t2.account_id AND t1.fund_id = t2.fund_id
--   AND t1.transaction_date = t2.transaction_date
--   AND t1.transaction_type = t2.transaction_type
--   AND t1.units = t2.units AND t1.amount = t2.amount
--   AND t1.transaction_id > t2.transaction_id;

-- Mark the stuck pending trade as failed:
-- UPDATE transactions SET status = 'Failed'
-- WHERE status = 'Pending' AND transaction_date = '2026-09-20';
