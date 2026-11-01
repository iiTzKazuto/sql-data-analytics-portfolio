-- =====================================================================
-- NORTHGATE BANK OPERATIONS DATABASE            FILE 3 OF 3: ANALYSIS
-- ---------------------------------------------------------------------
-- The bank's operations team has asked for answers to real questions.
-- Each query below answers one of them.
--
-- BEFORE YOU START
--   Run bank_01_schema.sql, then load your cleaned data (or run
--   bank_02_load_clean_data.sql).
--
-- HOW TO USE THIS FILE IN MYSQL WORKBENCH
--   1. File > Open SQL Script...  and choose this file.
--   2. Do NOT run the whole file at once. Click inside ONE query and
--      press Ctrl+Enter to run just that query.
--   3. Read the comment above each query: it says what question it
--      answers and what to look for in the result.
--
-- "Today" in this project is 2026-09-30 (the end of the data).
-- Money is in US dollars.
-- =====================================================================

USE bank_ops;

-- =====================================================================
-- SECTION A: CHECK THE LOAD
-- Always check that the data arrived correctly before you analyse it.
-- =====================================================================

-- A1) Row count in each table
--     With the answer-key data you should see: branches 5, customers 500,
--     accounts 694, transactions 10795, loans 180, loan_payments 3748.
--     Your own cleaned data may differ by a few rows. If so, find out why.
SELECT 'branches' AS table_name, COUNT(*) AS row_count FROM branches
UNION ALL SELECT 'customers',     COUNT(*) FROM customers
UNION ALL SELECT 'accounts',      COUNT(*) FROM accounts
UNION ALL SELECT 'transactions',  COUNT(*) FROM transactions
UNION ALL SELECT 'loans',         COUNT(*) FROM loans
UNION ALL SELECT 'loan_payments', COUNT(*) FROM loan_payments;

-- A2) Orphan check: rows that point to something that does not exist.
--     Every number should be 0. (The foreign keys also stop these from loading.)
SELECT 'transactions without an account' AS problem, COUNT(*) AS rows_found
FROM transactions t LEFT JOIN accounts a ON a.account_no = t.account_no WHERE a.account_no IS NULL
UNION ALL
SELECT 'accounts without a customer', COUNT(*)
FROM accounts a LEFT JOIN customers c ON c.customer_id = a.customer_id WHERE c.customer_id IS NULL
UNION ALL
SELECT 'loans without a customer', COUNT(*)
FROM loans l LEFT JOIN customers c ON c.customer_id = l.customer_id WHERE c.customer_id IS NULL
UNION ALL
SELECT 'payments without a loan', COUNT(*)
FROM loan_payments p LEFT JOIN loans l ON l.loan_id = p.loan_id WHERE l.loan_id IS NULL;

-- A3) Date check: transactions outside the period 2026-01-01 to 2026-09-30.
--     Should be 0. If not, a typo year (like 2062) slipped through cleaning.
SELECT COUNT(*) AS transactions_outside_period
FROM transactions
WHERE txn_date < '2026-01-01' OR txn_date > '2026-09-30';

-- A4) Account opened before the customer signed up? Should be 0.
SELECT COUNT(*) AS accounts_before_signup
FROM accounts a JOIN customers c ON c.customer_id = a.customer_id
WHERE a.open_date < c.signup_date;

-- =====================================================================
-- SECTION B: CUSTOMERS AND ACCOUNTS
-- =====================================================================

-- B1) How much money does each branch hold? (open accounts only)
SELECT  b.branch_name,
        b.city,
        COUNT(*)                          AS open_accounts,
        ROUND(SUM(a.stated_balance), 2)   AS total_deposits,
        ROUND(AVG(a.stated_balance), 2)   AS avg_balance
FROM accounts a
JOIN branches b ON b.branch_id = a.branch_id
WHERE a.status = 'Open'
GROUP BY b.branch_id, b.branch_name, b.city
ORDER BY total_deposits DESC;

-- B2) Which account types matter most?
SELECT  account_type,
        COUNT(*)                          AS accounts,
        ROUND(SUM(stated_balance), 2)     AS total_balance,
        ROUND(AVG(stated_balance), 2)     AS avg_balance
FROM accounts
WHERE status = 'Open'
GROUP BY account_type
ORDER BY total_balance DESC;

-- B3) Top 10 customers by total balance
SELECT customer, city, open_accounts, total_balance, loans
FROM v_customer_360
ORDER BY total_balance DESC
LIMIT 10;

-- B4) Cross-sell list: active customers with a Checking account but NO Savings account.
--     These are the customers the bank could offer a savings account to.
SELECT  c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer,
        c.city,
        ROUND(SUM(a.stated_balance), 2)         AS checking_balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id AND a.status = 'Open' AND a.account_type = 'Checking'
WHERE c.status = 'Active'
  AND NOT EXISTS (SELECT 1 FROM accounts s
                  WHERE s.customer_id = c.customer_id AND s.account_type = 'Savings' AND s.status = 'Open')
GROUP BY c.customer_id, c.first_name, c.last_name, c.city
ORDER BY checking_balance DESC
LIMIT 20;

-- B5) Customers by age group, with average balance
SELECT  CASE WHEN age < 25 THEN 'Under 25'
             WHEN age < 35 THEN '25-34'
             WHEN age < 50 THEN '35-49'
             WHEN age < 65 THEN '50-64'
             ELSE '65 and over' END       AS age_group,
        COUNT(*)                          AS customers,
        ROUND(AVG(total_balance), 2)      AS avg_total_balance
FROM (SELECT c.customer_id,
             TIMESTAMPDIFF(YEAR, c.birth_date, '2026-09-30') AS age,
             v.total_balance
      FROM customers c
      JOIN v_customer_360 v ON v.customer_id = c.customer_id
      WHERE c.status = 'Active') x
GROUP BY age_group
ORDER BY MIN(age);

-- B6) Customers who are marked Active but have no open account
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer, c.signup_date
FROM customers c
WHERE c.status = 'Active'
  AND NOT EXISTS (SELECT 1 FROM accounts a WHERE a.customer_id = c.customer_id AND a.status = 'Open')
ORDER BY c.signup_date;

-- =====================================================================
-- SECTION C: TRANSACTION ANALYSIS
-- =====================================================================

-- C1) Monthly money in, money out, and net flow
SELECT  DATE_FORMAT(txn_date, '%Y-%m')                                                        AS month,
        COUNT(*)                                                                              AS transactions,
        ROUND(SUM(CASE WHEN txn_type IN ('Deposit', 'Transfer In', 'Interest') THEN amount END), 2) AS money_in,
        ROUND(SUM(CASE WHEN txn_type IN ('Withdrawal', 'Transfer Out', 'Fee')  THEN amount END), 2) AS money_out,
        ROUND(SUM(CASE WHEN txn_type IN ('Deposit', 'Transfer In', 'Interest') THEN amount
                       ELSE -amount END), 2)                                                  AS net_flow
FROM transactions
GROUP BY DATE_FORMAT(txn_date, '%Y-%m')
ORDER BY month;

-- C2) Which channels do customers actually use? (System entries are not customer choices)
SELECT  channel,
        COUNT(*)                                                         AS transactions,
        ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                 AS pct_of_customer_transactions,
        ROUND(AVG(amount), 2)                                            AS avg_amount
FROM transactions
WHERE channel <> 'System'
GROUP BY channel
ORDER BY transactions DESC;

-- C3) Fee income and interest paid, by month
SELECT  DATE_FORMAT(txn_date, '%Y-%m')                                   AS month,
        ROUND(SUM(CASE WHEN txn_type = 'Fee'      THEN amount END), 2)   AS fee_income,
        ROUND(SUM(CASE WHEN txn_type = 'Interest' THEN amount END), 2)   AS interest_paid
FROM transactions
WHERE txn_type IN ('Fee', 'Interest')
GROUP BY DATE_FORMAT(txn_date, '%Y-%m')
ORDER BY month;

-- C4) Which weekday is busiest for customer transactions?
SELECT  DAYNAME(txn_date)   AS weekday,
        COUNT(*)            AS transactions
FROM transactions
WHERE channel <> 'System'
GROUP BY DAYNAME(txn_date), WEEKDAY(txn_date)
ORDER BY WEEKDAY(txn_date);

-- C5) The 15 largest transactions, with customer names
SELECT  t.txn_id, t.txn_date, t.txn_type, t.amount, t.channel,
        CONCAT(c.first_name, ' ', c.last_name) AS customer
FROM transactions t
JOIN accounts a  ON a.account_no  = t.account_no
JOIN customers c ON c.customer_id = a.customer_id
ORDER BY t.amount DESC
LIMIT 15;

-- C6) Running total of net deposits across the year (window function)
WITH monthly AS (
    SELECT DATE_FORMAT(txn_date, '%Y-%m') AS month,
           SUM(CASE WHEN txn_type IN ('Deposit', 'Transfer In', 'Interest') THEN amount ELSE -amount END) AS net_flow
    FROM transactions
    GROUP BY DATE_FORMAT(txn_date, '%Y-%m')
)
SELECT month,
       ROUND(net_flow, 2)                                AS net_flow,
       ROUND(SUM(net_flow) OVER (ORDER BY month), 2)     AS running_total
FROM monthly;

-- =====================================================================
-- SECTION D: RECONCILIATION
-- Operations asks: "Does the balance our system shows match the balance
-- we get when we add up every transaction?" This is a core banking task.
-- =====================================================================

-- D1) Summary of the reconciliation
SELECT  COUNT(*)                                          AS accounts_checked,
        SUM(difference <> 0)                              AS accounts_with_a_break,
        ROUND(SUM(ABS(difference)), 2)                    AS total_break_amount,
        MAX(ABS(difference))                              AS largest_break
FROM v_account_balance;

-- D2) The accounts that do not reconcile, largest first
--     difference = stated balance minus computed balance.
--     A positive difference means the system shows MORE money than the transactions explain.
SELECT  b.account_no,
        CONCAT(c.first_name, ' ', c.last_name) AS customer,
        b.account_type,
        b.stated_balance,
        b.computed_balance,
        b.difference
FROM v_account_balance b
JOIN customers c ON c.customer_id = b.customer_id
WHERE b.difference <> 0
ORDER BY ABS(b.difference) DESC;

-- D3) Breaks by branch: is the problem concentrated in one place?
SELECT  br.branch_name,
        COUNT(*)                                AS accounts,
        SUM(b.difference <> 0)                  AS breaks,
        ROUND(100 * SUM(b.difference <> 0) / COUNT(*), 1) AS break_rate_pct,
        ROUND(SUM(ABS(b.difference)), 2)        AS total_break_amount
FROM v_account_balance b
JOIN branches br ON br.branch_id = b.branch_id
GROUP BY br.branch_id, br.branch_name
ORDER BY breaks DESC;

-- D4) Possible double-postings: the same bill, withdrawal or purchase posted twice
--     (same account, date, type, amount, and channel). Each extra copy may need to be refunded.
SELECT  t.account_no,
        t.txn_date,
        t.txn_type,
        t.description,
        t.amount,
        COUNT(*)                          AS times_posted,
        ROUND(t.amount * (COUNT(*) - 1), 2) AS possible_overcharge
FROM transactions t
WHERE t.txn_type IN ('Withdrawal', 'Fee')
GROUP BY t.account_no, t.txn_date, t.txn_type, t.description, t.amount, t.channel
HAVING COUNT(*) > 1
ORDER BY possible_overcharge DESC;

-- D5) Total possible overcharge from double-postings
SELECT  COUNT(*)                                       AS duplicate_groups,
        ROUND(SUM(possible_overcharge), 2)             AS total_to_review
FROM (SELECT t.amount * (COUNT(*) - 1) AS possible_overcharge
      FROM transactions t
      WHERE t.txn_type IN ('Withdrawal', 'Fee')
      GROUP BY t.account_no, t.txn_date, t.txn_type, t.description, t.amount, t.channel
      HAVING COUNT(*) > 1) d;

-- =====================================================================
-- SECTION E: RISK AND COMPLIANCE
-- Banks must watch for suspicious activity (anti-money-laundering, AML).
-- These queries flag accounts for a human to review. They do not prove
-- anything is wrong.
-- =====================================================================

-- E1) Possible "structuring": 3 or more cash deposits between $9,000 and $9,999
--     within 7 days. Splitting deposits to stay under the $10,000 reporting
--     threshold is a classic warning sign.
WITH d AS (
    SELECT account_no, txn_date, amount
    FROM transactions
    WHERE txn_type = 'Deposit' AND amount BETWEEN 9000 AND 9999.99
),
windows AS (
    SELECT d1.account_no,
           d1.txn_date                AS window_start,
           COUNT(*)                   AS deposits_in_7_days,
           SUM(d2.amount)             AS total_deposited
    FROM d d1
    JOIN d d2 ON d2.account_no = d1.account_no
             AND d2.txn_date BETWEEN d1.txn_date AND DATE_ADD(d1.txn_date, INTERVAL 6 DAY)
    GROUP BY d1.account_no, d1.txn_date
    HAVING COUNT(*) >= 3
)
SELECT  w.account_no,
        CONCAT(c.first_name, ' ', c.last_name) AS customer,
        MIN(w.window_start)                    AS first_window,
        MAX(w.deposits_in_7_days)              AS most_deposits_in_7_days,
        ROUND(MAX(w.total_deposited), 2)       AS total_deposited
FROM windows w
JOIN accounts a  ON a.account_no  = w.account_no
JOIN customers c ON c.customer_id = a.customer_id
GROUP BY w.account_no, c.first_name, c.last_name
ORDER BY total_deposited DESC;

-- E2) Large transactions: $20,000 or more
SELECT  t.txn_id, t.txn_date, t.account_no,
        CONCAT(c.first_name, ' ', c.last_name) AS customer,
        t.txn_type, t.amount, t.description
FROM transactions t
JOIN accounts a  ON a.account_no  = t.account_no
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.amount >= 20000
ORDER BY t.amount DESC;

-- E3) Rapid in-and-out: a large deposit followed within 2 days by a transfer out
--     of 90 percent or more of it. Money passing straight through an account.
SELECT  d.account_no,
        CONCAT(c.first_name, ' ', c.last_name)          AS customer,
        d.txn_date                                      AS deposit_date,
        d.amount                                        AS deposited,
        o.txn_date                                      AS transfer_out_date,
        o.amount                                        AS transferred_out,
        ROUND(100 * o.amount / d.amount, 1)             AS pct_sent_out
FROM transactions d
JOIN transactions o ON o.account_no = d.account_no
                   AND o.txn_type = 'Transfer Out'
                   AND o.txn_date BETWEEN d.txn_date AND DATE_ADD(d.txn_date, INTERVAL 2 DAY)
                   AND o.amount >= 0.9 * d.amount
JOIN accounts a  ON a.account_no  = d.account_no
JOIN customers c ON c.customer_id = a.customer_id
WHERE d.txn_type = 'Deposit' AND d.amount >= 20000
ORDER BY d.amount DESC;

-- E4) Inactive accounts: open accounts with a balance but no customer activity
--     (deposit, withdrawal or transfer) in the last 90 days. Interest and
--     fees do not count because the bank posts those, not the customer.
SELECT  br.branch_name,
        COUNT(*)                          AS inactive_accounts,
        ROUND(SUM(a.stated_balance), 2)   AS money_sitting_idle
FROM accounts a
JOIN branches br ON br.branch_id = a.branch_id
WHERE a.status = 'Open'
  AND a.stated_balance > 0
  AND NOT EXISTS (SELECT 1 FROM transactions t
                  WHERE t.account_no = a.account_no
                    AND t.txn_type IN ('Deposit', 'Withdrawal', 'Transfer In', 'Transfer Out')
                    AND t.txn_date > DATE_SUB('2026-09-30', INTERVAL 90 DAY))
GROUP BY br.branch_id, br.branch_name
ORDER BY money_sitting_idle DESC;

-- E5) Overdrawn accounts (negative balance)
SELECT  a.account_no,
        CONCAT(c.first_name, ' ', c.last_name) AS customer,
        a.account_type,
        a.stated_balance
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
WHERE a.status = 'Open' AND a.stated_balance < 0
ORDER BY a.stated_balance;

-- E6) Closed accounts that still show a balance (money that should not be there)
SELECT account_no, account_type, stated_balance
FROM accounts
WHERE status = 'Closed' AND stated_balance <> 0;

-- =====================================================================
-- SECTION F: LOANS
-- =====================================================================

-- F1) The loan portfolio by type and status
SELECT  loan_type,
        status,
        COUNT(*)                          AS loans,
        ROUND(SUM(principal), 2)          AS total_principal,
        ROUND(100 * AVG(annual_rate), 2)  AS avg_rate_pct
FROM loans
GROUP BY loan_type, status
ORDER BY loan_type, FIELD(status, 'Current', 'Delinquent', 'Default', 'Paid Off');

-- F2) Delinquency rate by loan type
--     Delinquency rate = loans with at least one missed payment / loans still open
SELECT  loan_type,
        COUNT(*)                                                    AS open_loans,
        SUM(payments_missed > 0)                                    AS loans_with_missed_payments,
        ROUND(100 * SUM(payments_missed > 0) / COUNT(*), 1)         AS delinquency_rate_pct,
        ROUND(SUM(overdue_amount), 2)                               AS total_overdue
FROM v_loan_summary
WHERE status <> 'Paid Off'
GROUP BY loan_type
ORDER BY delinquency_rate_pct DESC;

-- F3) Collections list: the 15 loans with the most money overdue,
--     with the customer's phone number so collections can call.
SELECT  s.loan_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer,
        c.phone,
        s.loan_type,
        s.status,
        s.payments_missed,
        s.overdue_amount,
        s.days_past_due
FROM v_loan_summary s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.payments_missed > 0
ORDER BY s.overdue_amount DESC
LIMIT 15;

-- F4) Wrong loan status: loans labelled "Current" that have missed 2 or more payments.
--     The status field is out of date, so the risk report is understating problems.
SELECT  s.loan_id, s.customer_id, s.loan_type, s.status,
        s.payments_missed, s.overdue_amount, s.days_past_due
FROM v_loan_summary s
WHERE s.status = 'Current' AND s.payments_missed >= 2
ORDER BY s.payments_missed DESC;

-- F5) Aging report: how late are the overdue loans? (buckets used in bank risk reports)
SELECT  CASE WHEN days_past_due <= 30 THEN '1-30 days'
             WHEN days_past_due <= 60 THEN '31-60 days'
             WHEN days_past_due <= 90 THEN '61-90 days'
             ELSE 'Over 90 days' END   AS days_overdue,
        COUNT(*)                       AS loans,
        ROUND(SUM(overdue_amount), 2)  AS overdue_amount
FROM v_loan_summary
WHERE payments_missed > 0
GROUP BY days_overdue
ORDER BY MIN(days_past_due);

-- F6) How well do customers pay? On-time rate and average days late, by loan type
SELECT  l.loan_type,
        COUNT(*)                                                            AS payments_made,
        ROUND(100 * SUM(p.paid_date <= p.due_date) / COUNT(*), 1)           AS paid_on_time_pct,
        ROUND(AVG(DATEDIFF(p.paid_date, p.due_date)), 1)                    AS avg_days_late
FROM loan_payments p
JOIN loans l ON l.loan_id = p.loan_id
WHERE p.paid_date IS NOT NULL
GROUP BY l.loan_type
ORDER BY paid_on_time_pct;

-- F7) Short payments: paid less than the amount due
SELECT  COUNT(*)                                         AS short_payments,
        ROUND(SUM(amount_due - amount_paid), 2)          AS total_shortfall
FROM loan_payments
WHERE paid_date IS NOT NULL AND amount_paid < amount_due;

-- F8) Estimated monthly interest income from open loans (simple: principal x rate / 12)
SELECT  loan_type,
        COUNT(*)                                           AS open_loans,
        ROUND(SUM(principal), 2)                           AS total_principal,
        ROUND(SUM(principal * annual_rate / 12), 2)        AS est_monthly_interest
FROM loans
WHERE status <> 'Paid Off'
GROUP BY loan_type
ORDER BY est_monthly_interest DESC;

-- F9) Collections idea: overdue customers who have enough money in the bank.
--     A gentle reminder call may be enough for these, not a formal collections process.
SELECT  s.customer_id,
        v.customer,
        s.loan_id,
        s.overdue_amount,
        v.total_balance
FROM v_loan_summary s
JOIN v_customer_360 v ON v.customer_id = s.customer_id
WHERE s.payments_missed > 0
  AND v.total_balance >= s.overdue_amount * 2
ORDER BY s.overdue_amount DESC;

-- F10) Customers with a delinquent or defaulted loan AND a low balance: the highest risk group
SELECT  s.customer_id,
        v.customer,
        s.loan_id,
        s.status,
        s.overdue_amount,
        v.total_balance
FROM v_loan_summary s
JOIN v_customer_360 v ON v.customer_id = s.customer_id
WHERE s.status IN ('Delinquent', 'Default')
  AND v.total_balance < s.overdue_amount
ORDER BY s.overdue_amount DESC;

-- =====================================================================
-- SECTION G: ONE-PAGE SUMMARY FOR MANAGEMENT
-- =====================================================================

-- G1) Key numbers in one row
SELECT
    (SELECT COUNT(*) FROM customers WHERE status = 'Active')                           AS active_customers,
    (SELECT COUNT(*) FROM accounts  WHERE status = 'Open')                             AS open_accounts,
    (SELECT ROUND(SUM(stated_balance), 2) FROM accounts WHERE status = 'Open')         AS total_deposits,
    (SELECT ROUND(SUM(principal), 2) FROM loans WHERE status <> 'Paid Off')            AS loans_outstanding,
    (SELECT ROUND(SUM(overdue_amount), 2) FROM v_loan_summary)                         AS loans_overdue,
    (SELECT SUM(difference <> 0) FROM v_account_balance)                               AS accounts_not_reconciling,
    (SELECT COUNT(*) FROM v_loan_summary WHERE status = 'Current' AND payments_missed >= 2) AS loans_wrongly_marked_current;
