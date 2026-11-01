-- =====================================================================
-- EMPLOYEE MANAGEMENT DATABASE  (MySQL 8.0)
-- ---------------------------------------------------------------------
-- HOW TO RUN THIS FILE IN MYSQL WORKBENCH
--   1. File > Open SQL Script...  and choose this file.
--   2. Press Ctrl+Shift+Enter  (runs the WHOLE script, top to bottom).
--      Do NOT use plain Ctrl+Enter, that only runs one statement.
--   3. In the Schemas panel on the left, right-click and choose
--      "Refresh All". You will see a new database: employee_mgmt.
--   4. Run any query from the EXAMPLE QUERIES section at the bottom:
--      click inside the query and press Ctrl+Enter.
--
-- NOTE: This script creates a NEW database called employee_mgmt, so your
-- old `mydb` is untouched. If you run the script again, it deletes
-- employee_mgmt and rebuilds it from scratch.
-- =====================================================================

DROP DATABASE IF EXISTS employee_mgmt;
CREATE DATABASE employee_mgmt;
USE employee_mgmt;

-- ---------------------------------------------------------------------
-- 1. DEPARTMENTS
-- ---------------------------------------------------------------------
CREATE TABLE departments (
    department_id   INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(50) NOT NULL UNIQUE,
    location        VARCHAR(50)
);

-- ---------------------------------------------------------------------
-- 2. JOBS (job titles with an allowed pay range)
-- ---------------------------------------------------------------------
CREATE TABLE jobs (
    job_id         INT AUTO_INCREMENT PRIMARY KEY,
    job_title      VARCHAR(50)  NOT NULL UNIQUE,
    min_hourly_pay DECIMAL(6,2) NOT NULL,
    max_hourly_pay DECIMAL(6,2) NOT NULL,
    CHECK (min_hourly_pay <= max_hourly_pay)
);

-- ---------------------------------------------------------------------
-- 3. EMPLOYEES
--    manager_id points back to employees (an employee's boss is also
--    an employee).
-- ---------------------------------------------------------------------
CREATE TABLE employees (
    employee_id   INT AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    email         VARCHAR(100) UNIQUE,
    phone_number  VARCHAR(20),
    hire_date     DATE         NOT NULL,
    hourly_pay    DECIMAL(6,2) NOT NULL CHECK (hourly_pay > 0),
    department_id INT,
    job_id        INT,
    manager_id    INT,
    FOREIGN KEY (department_id) REFERENCES departments(department_id),
    FOREIGN KEY (job_id)        REFERENCES jobs(job_id),
    FOREIGN KEY (manager_id)    REFERENCES employees(employee_id)
);

-- ---------------------------------------------------------------------
-- 4. TIMESHEETS (hours worked per employee per day)
-- ---------------------------------------------------------------------
CREATE TABLE timesheets (
    timesheet_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id  INT NOT NULL,
    work_date    DATE NOT NULL,
    hours_worked DECIMAL(4,2) NOT NULL CHECK (hours_worked BETWEEN 0 AND 24),
    UNIQUE (employee_id, work_date),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
        ON DELETE CASCADE
);

-- =====================================================================
-- SAMPLE DATA
-- =====================================================================

INSERT INTO departments (department_id, department_name, location) VALUES
    (1, 'Executive',        'Head Office'),
    (2, 'Human Resources',  'Floor 2'),
    (3, 'Finance',          'Floor 2'),
    (4, 'Sales',            'Floor 3'),
    (5, 'IT',               'Floor 4'),
    (6, 'Operations',       'Warehouse');

INSERT INTO jobs (job_id, job_title, min_hourly_pay, max_hourly_pay) VALUES
    (1,  'CEO',                   50.00, 70.00),
    (2,  'Department Manager',    30.00, 40.00),
    (3,  'HR Specialist',         20.00, 24.00),
    (4,  'Accountant',            24.00, 30.00),
    (5,  'Sales Representative',  17.00, 21.00),
    (6,  'Software Developer',    33.00, 40.00),
    (7,  'IT Support Specialist', 20.00, 23.00),
    (8,  'Operations Associate',  15.00, 18.00),
    (9,  'Warehouse Clerk',       13.00, 16.00),
    (10, 'Customer Service Rep',  15.00, 17.00);

-- Employees (the CEO is first, then department managers, then staff,
-- so every manager_id points to a row that already exists)
INSERT INTO employees
    (employee_id, first_name, last_name, email, phone_number, hire_date, hourly_pay, department_id, job_id, manager_id)
VALUES
    -- Executive
    (1,  'Margaret',  'Thompson',  'margaret.thompson@company.example', '555-0101', '2018-03-12', 55.00, 1, 1, NULL),

    -- Department managers (report to the CEO)
    (2,  'Robert',    'Chen',      'robert.chen@company.example',       '555-0102', '2018-06-04', 32.00, 2, 2, 1),
    (3,  'Linda',     'Okafor',    'linda.okafor@company.example',      '555-0103', '2018-09-17', 33.50, 3, 2, 1),
    (4,  'James',     'Patel',     'james.patel@company.example',       '555-0104', '2019-01-21', 34.00, 4, 2, 1),
    (5,  'Sarah',     'Johnson',   'sarah.johnson@company.example',     '555-0105', '2019-02-11', 38.00, 5, 2, 1),
    (6,  'Michael',   'Rodriguez', 'michael.rodriguez@company.example', '555-0106', '2019-05-06', 31.00, 6, 2, 1),

    -- Human Resources (manager: Robert Chen, id 2)
    (7,  'Emily',     'Carter',    'emily.carter@company.example',      '555-0107', '2020-02-03', 21.50, 2, 3, 2),
    (8,  'Daniel',    'Kim',       'daniel.kim@company.example',        '555-0108', '2021-07-19', 20.75, 2, 3, 2),
    (9,  'Olivia',    'Nguyen',    'olivia.nguyen@company.example',     '555-0109', '2022-04-25', 22.00, 2, 3, 2),

    -- Finance (manager: Linda Okafor, id 3)
    (10, 'Ethan',     'Brooks',    'ethan.brooks@company.example',      '555-0110', '2019-10-14', 26.00, 3, 4, 3),
    (11, 'Priya',     'Sharma',    'priya.sharma@company.example',      '555-0111', '2020-08-31', 27.50, 3, 4, 3),
    (12, 'Lucas',     'Fernandez', 'lucas.fernandez@company.example',   '555-0112', '2023-01-09', 24.75, 3, 4, 3),
    (13, 'Hannah',    'Schmidt',   'hannah.schmidt@company.example',    '555-0113', '2021-11-15', 25.50, 3, 4, 3),

    -- Sales (manager: James Patel, id 4)
    (14, 'Sophia',    'Williams',  'sophia.williams@company.example',   '555-0114', '2020-03-23', 19.00, 4, 5, 4),
    (15, 'Marcus',    'Johnson',   'marcus.johnson@company.example',    '555-0115', '2021-02-08', 18.50, 4, 5, 4),
    (16, 'Isabella',  'Rossi',     'isabella.rossi@company.example',    '555-0116', '2019-09-30', 20.25, 4, 5, 4),
    (17, 'Noah',      'Anderson',  'noah.anderson@company.example',     '555-0117', '2024-05-13', 17.75, 4, 5, 4),
    (18, 'Amara',     'Diallo',    'amara.diallo@company.example',      '555-0118', '2022-08-22', 19.50, 4, 5, 4),
    (19, 'Tyler',     'Reed',      'tyler.reed@company.example',        '555-0119', '2023-06-05', 18.00, 4, 5, 4),
    (20, 'Kevin',     'Murphy',    'kevin.murphy@company.example',      '555-0120', '2023-10-02', 18.25, 4, 5, 4),
    (21, 'Julia',     'Novak',     'julia.novak@company.example',       '555-0121', '2022-01-17', 19.25, 4, 5, 4),

    -- IT (manager: Sarah Johnson, id 5)
    (22, 'Aiden',     'Walker',    'aiden.walker@company.example',      '555-0122', '2019-07-08', 36.00, 5, 6, 5),
    (23, 'Mei',       'Lin',       'mei.lin@company.example',           '555-0123', '2020-11-02', 37.50, 5, 6, 5),
    (24, 'Carlos',    'Mendoza',   'carlos.mendoza@company.example',    '555-0124', '2022-03-14', 35.25, 5, 6, 5),
    (25, 'Fatima',    'Hassan',    'fatima.hassan@company.example',     '555-0125', '2024-09-09', 34.00, 5, 6, 5),
    (26, 'Jacob',     'Turner',    'jacob.turner@company.example',      '555-0126', '2021-05-24', 22.00, 5, 7, 5),
    (27, 'Grace',     'Lee',       'grace.lee@company.example',         '555-0127', '2023-03-20', 21.00, 5, 7, 5),
    (28, 'Samuel',    'Adeyemi',   'samuel.adeyemi@company.example',    '555-0128', '2024-01-15', 21.50, 5, 7, 5),

    -- Operations (manager: Michael Rodriguez, id 6)
    (29, 'William',   'Harris',    'william.harris@company.example',    '555-0129', '2019-11-04', 16.50, 6, 8, 6),
    (30, 'Chloe',     'Bennett',   'chloe.bennett@company.example',     '555-0130', '2022-06-13', 15.75, 6, 8, 6),
    (31, 'Anthony',   'Castillo',  'anthony.castillo@company.example',  '555-0131', '2020-09-28', 17.00, 6, 8, 6),
    (32, 'Ava',       'Mitchell',  'ava.mitchell@company.example',      '555-0132', '2025-02-10', 16.00, 6, 8, 6),
    (33, 'Zoe',       'Campbell',  'zoe.campbell@company.example',      '555-0133', '2023-08-07', 14.50, 6, 9, 6),
    (34, 'Henry',     'Foster',    'henry.foster@company.example',      '555-0134', '2021-04-19', 14.00, 6, 9, 6),
    (35, 'Layla',     'Ahmed',     'layla.ahmed@company.example',       '555-0135', '2024-03-04', 15.00, 6, 9, 6),
    (36, 'Victor',    'Alvarez',   'victor.alvarez@company.example',    '555-0136', '2025-06-16', 14.25, 6, 9, 6),
    (37, 'Benjamin',  'Scott',     'benjamin.scott@company.example',    '555-0137', '2022-10-31', 16.00, 6, 10, 6),
    (38, 'Natalie',   'Wright',    'natalie.wright@company.example',    '555-0138', '2021-12-06', 16.25, 6, 10, 6),
    (39, 'Omar',      'Khalil',    'omar.khalil@company.example',       '555-0139', '2024-07-22', 15.50, 6, 10, 6),
    (40, 'Rachel',    'Morgan',    'rachel.morgan@company.example',     '555-0140', '2023-05-29', 15.75, 6, 10, 6);

-- Timesheets: two work weeks (Mon-Fri, Oct 5-16 2026) for every employee
-- except the CEO. Hours are generated as 7, 7.5, or 8 per day.
INSERT INTO timesheets (employee_id, work_date, hours_worked)
WITH RECURSIVE days AS (
    SELECT DATE('2026-10-05') AS work_date
    UNION ALL
    SELECT work_date + INTERVAL 1 DAY FROM days WHERE work_date < '2026-10-16'
)
SELECT e.employee_id,
       d.work_date,
       7 + ((e.employee_id + DAY(d.work_date)) % 3) * 0.5
FROM employees e
CROSS JOIN days d
WHERE WEEKDAY(d.work_date) < 5      -- 0 = Monday ... 4 = Friday
  AND e.employee_id <> 1;

-- Quick check: how many rows were created in each table?
SELECT 'departments' AS table_name, COUNT(*) AS row_count FROM departments
UNION ALL SELECT 'jobs',       COUNT(*) FROM jobs
UNION ALL SELECT 'employees',  COUNT(*) FROM employees
UNION ALL SELECT 'timesheets', COUNT(*) FROM timesheets;

-- =====================================================================
-- EXAMPLE QUERIES
-- Click inside ONE query and press Ctrl+Enter to run just that one.
-- =====================================================================

-- 1) See everyone (the basic one)
SELECT * FROM employees;

-- 2) Everyone with their department, job title, and manager
SELECT  e.employee_id,
        CONCAT(e.first_name, ' ', e.last_name) AS employee,
        d.department_name,
        j.job_title,
        e.hourly_pay,
        CONCAT(m.first_name, ' ', m.last_name) AS manager
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id
LEFT JOIN jobs j        ON e.job_id        = j.job_id
LEFT JOIN employees m   ON e.manager_id    = m.employee_id
ORDER BY d.department_name, e.last_name;

-- 3) Headcount and average pay per department
SELECT  d.department_name,
        COUNT(e.employee_id)        AS headcount,
        ROUND(AVG(e.hourly_pay), 2) AS avg_hourly_pay
FROM departments d
LEFT JOIN employees e ON e.department_id = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY headcount DESC;

-- 4) Top 5 highest paid employees
SELECT first_name, last_name, hourly_pay
FROM employees
ORDER BY hourly_pay DESC
LIMIT 5;

-- 5) Search by name (finds anyone whose first name starts with "S")
SELECT * FROM employees
WHERE first_name LIKE 'S%';

-- 6) Employees hired in the last 2 years of data (since 2024-10-11)
SELECT first_name, last_name, hire_date
FROM employees
WHERE hire_date >= '2024-10-11'
ORDER BY hire_date DESC;

-- 7) Number of employees per job title
SELECT j.job_title, COUNT(e.employee_id) AS employees
FROM jobs j
LEFT JOIN employees e ON e.job_id = j.job_id
GROUP BY j.job_id, j.job_title
ORDER BY employees DESC;

-- 8) How many people report to each manager
SELECT  CONCAT(m.first_name, ' ', m.last_name) AS manager,
        COUNT(e.employee_id) AS direct_reports
FROM employees m
JOIN employees e ON e.manager_id = m.employee_id
GROUP BY m.employee_id, m.first_name, m.last_name
ORDER BY direct_reports DESC;

-- 9) Total hours and gross pay for the week of Oct 5-11, 2026
SELECT  CONCAT(e.first_name, ' ', e.last_name) AS employee,
        SUM(t.hours_worked)                 AS total_hours,
        SUM(t.hours_worked * e.hourly_pay)  AS gross_pay
FROM employees e
JOIN timesheets t ON t.employee_id = e.employee_id
WHERE t.work_date BETWEEN '2026-10-05' AND '2026-10-11'
GROUP BY e.employee_id, e.first_name, e.last_name
ORDER BY gross_pay DESC;

-- 10) Payroll cost per department for that same week
SELECT  d.department_name,
        ROUND(SUM(t.hours_worked * e.hourly_pay), 2) AS weekly_payroll
FROM timesheets t
JOIN employees e   ON t.employee_id   = e.employee_id
JOIN departments d ON e.department_id = d.department_id
WHERE t.work_date BETWEEN '2026-10-05' AND '2026-10-11'
GROUP BY d.department_id, d.department_name
ORDER BY weekly_payroll DESC;

-- 11) Data check: anyone paid outside their job's pay range?
--     (should return no rows)
SELECT e.first_name, e.last_name, j.job_title, e.hourly_pay
FROM employees e
JOIN jobs j ON e.job_id = j.job_id
WHERE e.hourly_pay NOT BETWEEN j.min_hourly_pay AND j.max_hourly_pay;

-- =====================================================================
-- UPDATE / DELETE / INSERT EXAMPLES
-- These are commented out so they don't run by accident.
-- To try one: delete the "-- " at the start of its lines, then run it.
-- =====================================================================

-- Give the whole IT department a $1.00 raise:
-- UPDATE employees
-- SET hourly_pay = hourly_pay + 1
-- WHERE department_id = 5;

-- Change one person's email:
-- UPDATE employees
-- SET email = 'emily.c@company.example'
-- WHERE employee_id = 7;

-- Add a new employee (employee_id is assigned automatically):
-- INSERT INTO employees
--     (first_name, last_name, email, phone_number, hire_date, hourly_pay, department_id, job_id, manager_id)
-- VALUES
--     ('Diego', 'Navarro', 'diego.navarro@company.example', '555-0141', '2026-10-12', 19.00, 4, 5, 4);

-- Remove an employee (their timesheets are deleted automatically):
-- DELETE FROM employees WHERE employee_id = 40;
