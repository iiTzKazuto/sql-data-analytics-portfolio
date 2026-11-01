-- =====================================================================
-- NORTHGATE BANK OPERATIONS DATABASE  (MySQL 8.0)       FILE 1 OF 3: SCHEMA
-- ---------------------------------------------------------------------
-- WHAT THIS FILE DOES
--   Builds an EMPTY database called bank_ops: the tables, the rules that
--   keep data clean (keys, allowed values), the indexes, and 3 views.
--   It does NOT load any data. You load your cleaned Excel data next.
--
-- HOW TO RUN IT IN MYSQL WORKBENCH
--   1. File > Open SQL Script...  and choose this file.
--   2. Press Ctrl+Shift+Enter  (runs the whole file).
--   3. Right-click in the Schemas panel > Refresh All. You will see
--      bank_ops with 6 tables.
--
-- NOTE: This deletes and rebuilds bank_ops if it already exists. Your
-- other databases are not touched.
--
-- WHAT COMES NEXT
--   Load your cleaned data (see the project guide), then open
--   bank_03_analysis.sql to answer the bank's questions.
--   Want to skip the cleaning for now? Run bank_02_load_clean_data.sql.
-- =====================================================================

DROP DATABASE IF EXISTS bank_ops;
CREATE DATABASE bank_ops;
USE bank_ops;

-- ---------------------------------------------------------------------
-- BRANCHES
-- ---------------------------------------------------------------------
CREATE TABLE branches (
    branch_id   CHAR(3)     PRIMARY KEY,
    branch_name VARCHAR(30) NOT NULL,
    city        VARCHAR(30) NOT NULL
);

-- ---------------------------------------------------------------------
-- CUSTOMERS
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id CHAR(5)      PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    birth_date  DATE         NOT NULL,
    email       VARCHAR(100),                       -- empty when missing or invalid
    phone       VARCHAR(12),                        -- 555-123-4567
    city        VARCHAR(30)  NOT NULL,
    signup_date DATE         NOT NULL,
    status      ENUM('Active', 'Inactive', 'Closed') NOT NULL
);

-- ---------------------------------------------------------------------
-- ACCOUNTS
--   opening_balance : balance on 2026-01-01 (0 if opened later)
--   stated_balance  : the balance the core banking system shows now
-- ---------------------------------------------------------------------
CREATE TABLE accounts (
    account_no      VARCHAR(10)   PRIMARY KEY,
    customer_id     CHAR(5)       NOT NULL,
    account_type    ENUM('Checking', 'Savings', 'Time Deposit') NOT NULL,
    branch_id       CHAR(3)       NOT NULL,
    open_date       DATE          NOT NULL,
    opening_balance DECIMAL(14,2) NOT NULL,
    stated_balance  DECIMAL(14,2) NOT NULL,
    status          ENUM('Open', 'Closed') NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (branch_id)   REFERENCES branches(branch_id)
);

-- ---------------------------------------------------------------------
-- TRANSACTIONS
--   amount is always positive. txn_type tells you the direction:
--     money IN : Deposit, Transfer In, Interest
--     money OUT: Withdrawal, Transfer Out, Fee
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    txn_id      CHAR(7)       PRIMARY KEY,
    account_no  VARCHAR(10)   NOT NULL,
    txn_date    DATE          NOT NULL,
    txn_type    ENUM('Deposit', 'Withdrawal', 'Transfer In', 'Transfer Out', 'Fee', 'Interest') NOT NULL,
    amount      DECIMAL(14,2) NOT NULL CHECK (amount > 0),
    channel     ENUM('ATM', 'Online', 'Branch', 'Mobile', 'System') NOT NULL,
    description VARCHAR(40),
    FOREIGN KEY (account_no) REFERENCES accounts(account_no)
);

-- ---------------------------------------------------------------------
-- LOANS
--   annual_rate is a fraction: 0.055 means 5.5 percent per year
-- ---------------------------------------------------------------------
CREATE TABLE loans (
    loan_id     CHAR(5)       PRIMARY KEY,
    customer_id CHAR(5)       NOT NULL,
    loan_type   ENUM('Personal', 'Auto', 'Home', 'Business') NOT NULL,
    principal   DECIMAL(12,2) NOT NULL CHECK (principal > 0),
    annual_rate DECIMAL(5,4)  NOT NULL,
    term_months INT           NOT NULL CHECK (term_months > 0),
    start_date  DATE          NOT NULL,
    status      ENUM('Current', 'Paid Off', 'Delinquent', 'Default') NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- ---------------------------------------------------------------------
-- LOAN_PAYMENTS (one row per scheduled monthly payment)
--   paid_date is empty when the payment has not been made
-- ---------------------------------------------------------------------
CREATE TABLE loan_payments (
    payment_id  CHAR(6)       PRIMARY KEY,
    loan_id     CHAR(5)       NOT NULL,
    due_date    DATE          NOT NULL,
    paid_date   DATE,
    amount_due  DECIMAL(10,2) NOT NULL,
    amount_paid DECIMAL(10,2) NOT NULL DEFAULT 0,
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
);

-- ---------------------------------------------------------------------
-- INDEXES (make big queries faster)
-- ---------------------------------------------------------------------
CREATE INDEX idx_txn_account_date ON transactions (account_no, txn_date);
CREATE INDEX idx_txn_date         ON transactions (txn_date);
CREATE INDEX idx_accounts_cust    ON accounts (customer_id);
CREATE INDEX idx_payments_loan    ON loan_payments (loan_id, due_date);
CREATE INDEX idx_loans_cust       ON loans (customer_id);

-- ---------------------------------------------------------------------
-- VIEWS (saved queries you can use like tables)
-- ---------------------------------------------------------------------

-- One row per account: the balance the system shows (stated), the balance
-- we calculate from the transactions (computed), and the difference.
CREATE VIEW v_account_balance AS
SELECT a.account_no,
       a.customer_id,
       a.branch_id,
       a.account_type,
       a.status,
       a.opening_balance,
       a.stated_balance,
       ROUND(COALESCE(t.net_amount, 0), 2)                               AS net_transactions,
       ROUND(a.opening_balance + COALESCE(t.net_amount, 0), 2)           AS computed_balance,
       ROUND(a.stated_balance - (a.opening_balance + COALESCE(t.net_amount, 0)), 2) AS difference
FROM accounts a
LEFT JOIN (SELECT account_no,
                  SUM(CASE WHEN txn_type IN ('Deposit', 'Transfer In', 'Interest') THEN amount ELSE -amount END) AS net_amount
           FROM transactions
           GROUP BY account_no) t ON t.account_no = a.account_no;

-- One row per loan: how many payments were due, made and missed, and how
-- much is overdue. "Today" in this project is 2026-09-30.
CREATE VIEW v_loan_summary AS
SELECT l.loan_id,
       l.customer_id,
       l.loan_type,
       l.principal,
       l.annual_rate,
       l.term_months,
       l.start_date,
       l.status,
       COUNT(p.payment_id)                                                     AS payments_due,
       COALESCE(SUM(p.paid_date IS NOT NULL), 0)                               AS payments_made,
       COALESCE(SUM(p.paid_date IS NULL), 0)                                   AS payments_missed,
       ROUND(COALESCE(SUM(CASE WHEN p.paid_date IS NULL THEN p.amount_due END), 0), 2) AS overdue_amount,
       MIN(CASE WHEN p.paid_date IS NULL THEN p.due_date END)                  AS oldest_unpaid_due,
       DATEDIFF('2026-09-30', MIN(CASE WHEN p.paid_date IS NULL THEN p.due_date END)) AS days_past_due
FROM loans l
LEFT JOIN loan_payments p ON p.loan_id = l.loan_id
GROUP BY l.loan_id, l.customer_id, l.loan_type, l.principal, l.annual_rate, l.term_months, l.start_date, l.status;

-- One row per customer: the full picture (accounts, money, loans)
CREATE VIEW v_customer_360 AS
SELECT c.customer_id,
       CONCAT(c.first_name, ' ', c.last_name)                       AS customer,
       c.city,
       c.status,
       c.signup_date,
       COALESCE(a.open_accounts, 0)                                 AS open_accounts,
       COALESCE(a.total_balance, 0)                                 AS total_balance,
       COALESCE(l.loans, 0)                                         AS loans,
       COALESCE(l.overdue_amount, 0)                                AS loan_overdue_amount
FROM customers c
LEFT JOIN (SELECT customer_id, COUNT(*) AS open_accounts, ROUND(SUM(stated_balance), 2) AS total_balance
           FROM accounts WHERE status = 'Open' GROUP BY customer_id) a ON a.customer_id = c.customer_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS loans, ROUND(SUM(overdue_amount), 2) AS overdue_amount
           FROM v_loan_summary WHERE status <> 'Paid Off' GROUP BY customer_id) l ON l.customer_id = c.customer_id;

SHOW TABLES;
