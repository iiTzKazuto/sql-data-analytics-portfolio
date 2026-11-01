# Bank Operations: From Messy Excel to MySQL

**In one line:** I took a messy bank data export, cleaned it in Excel, loaded it into MySQL, and used SQL to answer the kind of questions a bank's operations team asks.

## Why I built this

Most practice datasets are already clean. Real work isn't. I wanted to practice the whole path: a raw file, cleaning it, building a database, and then getting answers out of it. I also wanted a project that matches the bank and operations roles I'm applying for.

## How it went

**1. The raw file.** I started with an Excel export of 5 sheets and 16,093 rows, built to look like data typed in by different branches. It had duplicate rows, dates written four different ways, money stored as text (`$1,234.50`, `USD 1,234.50`, `(250.00)`), names in all capital letters, abbreviations like `Wdl` and `Trf In`, and a few typos in city names.

**2. Cleaning in Excel.** I used formulas like `TRIM`, `PROPER`, `DATEVALUE`, `SUBSTITUTE`, and `INDEX/MATCH` with lookup tables. I removed 156 duplicate rows. Twenty rows could not be fixed, either because the account number didn't exist or the amount was missing. I didn't guess. I moved them into an Exceptions list, which is what I'd want to hand back to whoever owns the data.

**3. The database.** I designed 6 tables (customers, accounts, transactions, loans, loan payments, branches) with primary and foreign keys, plus 3 views.

**4. The analysis.** I wrote 38 queries grouped into balance checks, transaction trends, reconciliation, risk and compliance, and loan performance.

## What the data showed

These numbers come from my made-up data, but they are the kind of findings an operations team would want:

- **22 accounts don't reconcile.** The balance the system shows does not match the sum of the transactions. The total gap is $1,691.50.
- **20 payments were posted twice**, worth $5,504.66 that may need to be refunded.
- **58 alerts for review:** 8 possible structuring cases (several cash deposits just under $10,000), 6 cases of money passing straight through an account, and 44 transactions of $20,000 or more.
- **26 of 146 open loans (17.8%) have missed payments**, with $157,670 overdue. 10 of those loans are more than 90 days late.
- **6 loans are marked "Current" but have missed 2 or more payments**, so the status field is out of date.

## What's in this folder

| File | What it is |
|---|---|
| `data/bank_raw_data.xlsx` | The messy export, exactly as I started |
| `data/bank_clean_answer_key.xlsx` | The cleaned version, with the rows I set aside and the lookup tables I used |
| `sql/bank_01_schema.sql` | Builds the empty database: tables, keys, indexes, views |
| `sql/bank_02_load_clean_data.sql` | Loads the cleaned data (about 16,000 rows) |
| `sql/bank_03_analysis.sql` | The 38 analysis queries |

## How to run it

1. Open `bank_01_schema.sql` in MySQL Workbench and run it with **Ctrl+Shift+Enter**.
2. Open `bank_02_load_clean_data.sql` and run it the same way. It takes a few seconds.
3. Open `bank_03_analysis.sql` and run the queries **one at a time** with Ctrl+Enter.

Want to try the cleaning yourself? Open `bank_raw_data.xlsx`, clean it, and compare your result with `bank_clean_answer_key.xlsx`.

## What I learned

- Cleaning is most of the work. Nothing loads into a strict database until the dates, amounts, and categories are consistent.
- Foreign keys are annoying until you see them catch a transaction for an account that doesn't exist. Then you're glad they are there.
- It's better to set aside a row you can't trust than to guess a value.
- Checking your totals after every step catches mistakes early.
- A reconciliation is just asking two sources of the same number whether they agree.

## Tools

Excel, MySQL 8.0, MySQL Workbench

## Screenshots

See the `screenshots` folder for the raw data, the cleaned data, and some query results.
