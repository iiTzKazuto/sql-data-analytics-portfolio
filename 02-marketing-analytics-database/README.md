# Marketing Analytics Database

**In one line:** The database of an online store, built so I could practice the questions a marketing analyst answers every week: which channels pay off, who the best customers are, and what to do with the budget.

## Why I built this

I study marketing, and I wanted to show I can back marketing decisions with data. Most of what I've read about marketing analytics is theory, so I built a database where I could calculate the numbers myself: ROAS, CAC, repeat purchase rate, and more.

## What's inside

A store with 8 marketing channels (email, Facebook, Instagram, Google Search, TikTok, YouTube, influencers, and organic search), 31 campaigns, and 11 tables with about 17,000 rows:

- Daily ad spend, impressions, and clicks (1,734 rows)
- 1,500 customers and 2,400 orders
- 5,924 leads, 298 social posts, and 6 A/B tests
- Monthly revenue and customer targets

The data is generated to behave like real marketing data, with strong and weak channels, busy and quiet months, one-time buyers and repeat buyers. Nothing in it is a real company.

## What I looked at

| Section | Questions it answers |
|---|---|
| Overview | How much did we spend and earn? Did we hit our monthly targets? |
| Channels and campaigns | Which channels earn their budget? Which campaigns should we scale, keep, or cut? |
| Customers | Who are our best customers? How many buy again? (RFM segments) |
| Products | Which categories make the most profit? Do discounts pay off? |
| Leads, social, tests | Which posts get engagement? Which A/B test versions really win? |
| Data validation | Are there duplicates, overspending, or orders that don't make sense? |

## What the data showed

In my made-up data:

- $189.7K of ad spend brought in $359.4K of revenue, an overall ROAS of 1.89.
- **Organic search (5.7x) and email (4.7x)** were the best channels. **TikTok (0.18x) and Instagram (0.20x)** returned less than 25 cents for every dollar spent.
- The 6 awareness campaigns show zero direct revenue. That doesn't make them failures, it means they should be judged on reach, not ROAS.
- About 58% of buyers ordered again (708 of 1,211).
- Only 3 of the 6 A/B tests had a clear winner. The other 3 were too close to call, so I wouldn't change anything based on them.

## Files

| File | What it is |
|---|---|
| `marketing_analytics_setup.sql` | Builds the database and loads all the data. Run it first. |
| `marketing_analytics_reports.sql` | 37 reports and data checks. Run them one at a time. |

## How to run it

1. Open `marketing_analytics_setup.sql` in MySQL Workbench and run it with **Ctrl+Shift+Enter**. It takes a few seconds.
2. Refresh the Schemas panel. You'll see a new database called `marketing_analytics`.
3. Open `marketing_analytics_reports.sql`. Click inside one query and press **Ctrl+Enter**. Don't run the whole file at once, because it opens about 40 result tabs.

## What I learned

- A single ROAS number for the whole business hides a lot. The channel level is where the decisions are.
- Window functions like `RANK`, `LAG`, and `NTILE` make questions like "growth since last month" and "top customers" much easier.
- Cheap customers are not always good customers, so CAC needs to be read together with customer value.
- An A/B test needs a significance check. A higher number alone doesn't mean it won.

## Tools

MySQL 8.0, MySQL Workbench

## Screenshots

See the `screenshots` folder.
