# Fund and Transaction Tracker

**In one line:** A small investment platform database, with SQL checks that hunt for mistakes in the data.

## Why I built this

I wanted to understand how data errors happen in finance, and how a person would find them before they cause problems. So I built a database for an investment platform and wrote queries that catch bad data.

## What's inside

6 tables (advisors, clients, funds, fund prices, accounts, and transactions) and 2 views, with 30 clients, 33 accounts, 9 funds, and 132 transactions.

I added a few mistakes on purpose so my checks would have something to find. This is different from my other projects, where the data is clean.

## The mistakes and the checks

I planted these, then wrote a query for each:

- A trade entered twice
- An amount that doesn't match units times price (2,600 instead of 2,500)
- A sale of more units than the account owned
- A trade stuck in Pending for over 3 weeks
- A failed trade that needed follow-up
- A trade in a fund that wasn't set up yet
- A purchase in a fund that had already closed
- A purchase in an account that had already been closed

There are 10 checks in total. The last one gives a summary of every problem found.

## Reports

- What each account owns, and what it's worth at the latest price
- Total portfolio value per client
- Total assets in each fund
- Monthly trade volume
- Each advisor's total client assets

## File

| File | What it is |
|---|---|
| `fund_transaction_tracker.sql` | Builds the database, loads the data, and has the reports and checks at the bottom |

## How to run it

1. Open `fund_transaction_tracker.sql` in MySQL Workbench and run it with **Ctrl+Shift+Enter**.
2. Refresh the Schemas panel. You'll see a database called `fund_tracker`.
3. Scroll to the **CHECKS** section. Click inside one query and press **Ctrl+Enter**.

## What I learned

- Writing a check taught me more than writing a report. You have to think about every way the data can be wrong.
- A holdings number is just buys minus sells, so a negative holding means something is broken.
- Views save you from copying the same long query over and over.

## Tools

MySQL 8.0, MySQL Workbench

## Screenshots

See the `screenshots` folder.
