# Employee Management Database

**In one line:** My first real database project. A company's employees, departments, jobs, and timesheets, with the queries an HR or payroll team would run.

## Why I built this

I had just started learning SQL and wanted to build something from scratch instead of only reading about it. An employee database was a good place to start because everyone understands how a company works.

## What's inside

4 tables: departments, jobs, employees, and timesheets. The sample data has 40 employees, 6 departments, 10 job titles, and 390 timesheet entries.

A few things I'm proud of for a first project:

- Each employee points to a department, a job title, and a manager. The manager is also an employee, so that table connects back to itself.
- Rules in the database stop bad data, such as a pay of zero or negative hours.
- Deleting an employee also deletes their timesheets, so nothing is left behind.

## Example queries

There are 11 queries at the bottom of the file, including:

- Every employee with their department, job, and manager
- Headcount and average pay per department
- The top 5 highest paid employees
- Total hours and pay for the week (payroll)
- A check that nobody is paid outside their job's pay range

The `UPDATE`, `DELETE`, and `INSERT` examples are commented out so they don't run by accident.

## File

| File | What it is |
|---|---|
| `employee_management.sql` | Builds the database, loads the data, and has the example queries |

## How to run it

1. Open `employee_management.sql` in MySQL Workbench and run it with **Ctrl+Shift+Enter**.
2. Refresh the Schemas panel. You'll see a database called `employee_mgmt`.
3. Scroll to the example queries. Click inside one and press **Ctrl+Enter**.

## What I learned

- How primary keys, foreign keys, and constraints keep data clean
- How `JOIN` connects tables, and why `LEFT JOIN` matters when something might be missing
- How `GROUP BY` and aggregate functions turn rows into answers
- That my later projects got more careful because of the mistakes I made here

## Tools

MySQL 8.0, MySQL Workbench

## Screenshots

See the `screenshots` folder.
