# Clarity Vaults app: market research

*Prepared 7 November 2026. Purpose: decide what the first version of the Clarity Vaults iOS app must do to be genuinely useful, and what can wait.*

---

## 1. Summary

- **People want to feel in control, not to be sold to.** The single biggest cause of 1–2★ reviews is **price, subscriptions and paywalls (32% of negative reviews)**. Hard-to-cancel trials and features moved behind paywalls generate the most anger.
- **Reliability beats features.** Bugs, crashes and *lost data* are the second biggest complaint (16.5%). Broken bank sync is third (13.8%), even in the market leaders.
- **Manual entry is not the enemy, but tedium is.** Positive reviewers often say tracking made them *more aware* of their spending (9.3% of 4–5★ reviews vs 1.8% of 1–2★). The answer is to make manual entry fast, not to remove it.
- **UK users have UK-specific gaps:** budgeting **payday to payday** (not 1st to 31st), **council tax over 10 months**, Direct Debits, and seeing **what's left until payday**.
- **Demand is rising.** UK Google searches for "budgeting app" have nearly doubled since 2022 and are up about 50% on 2025. They peak every **January**, with a smaller rise in **August/September**.
- **Two UK consumer apps have shut down** (Money Dashboard in 2023 and Moneyhub's consumer app), stranding users. Data that lives on your own phone, with export, is a selling point.

**Recommendation:** launch a **private, manual-first, UK-native** app with fast entry, payday-based budgeting, bill reminders, a cash forecast and a debt payoff planner. Price it **without a mandatory subscription**. Keep bank connections (open banking) for version 2, once there's evidence people will pay for it.

---

## 2. What I looked at (method)

| Source | What | Notes |
|---|---|---|
| **App Store reviews** | **6,646 reviews** across 20 budgeting, debt and bill apps (3,896 UK store, 2,750 US store); 3,524 from 2025–26 | Apple's public review feed, up to 500 most recent per app. Includes YNAB, Monarch, Copilot, Rocket Money, Snoop, HyperJar, Goodbudget, Spendee, Pennies, Fleur, Cleo, Debt Payoff Planner and others. **Emma's and Updraft's feeds returned no data.** |
| **App Store rankings** | UK store search for "budget planner", "money manager", "debt payoff", "bill reminder", "budget app" | Ranked by number of ratings to find the apps people actually use |
| **Google Trends** | UK, last 5 years | "budgeting app", "budget planner", "money tracker", "debt payoff", "bill reminder", related queries |
| **Community forums** | MoneySavingExpert forum, Monzo Community | **Reddit blocks Anthropic's tools**, so UK forums were used instead |
| **Web** | Comparison articles, open banking provider and regulation pages | Secondary sources, so treated with caution |

**How reviews were analysed:** each review was tagged against 18 themes using keyword rules (e.g. "subscription", "paywall", "cancel" → *Price*). Themes were compared between 1–2★ (1,819 reviews) and 4–5★ (4,325 reviews), then checked by reading samples. Keyword tagging is approximate: treat the percentages as **directional**, not exact.

---

## 3. What frustrates people (1–2★ reviews)

| Theme | % of 1–2★ reviews | % of 4–5★ reviews | What it means for us |
|---|---:|---:|---|
| **Price / subscription / paywall** | **32.4%** | 9.2% | Avoid aggressive subscriptions and dark patterns. Make cancelling obvious. |
| **Bugs, crashes, lost data** | **16.5%** | 2.6% | Keep v1 small and solid. Unit-test the maths. Offer export. |
| **Bank sync broken** | **13.8%** | 4.7% | Bank sync is a major source of anger even for well-funded apps. Don't make it the foundation. |
| **Poor customer support** | 10.8% | 5.0% | A clear help page, and fast replies from you as the founder, are a real differentiator. |
| **Hard to use / learning curve** | 8.4% | 3.9% | YNAB in particular (18% of its negative reviews). Plain English, sensible defaults. |
| **Bills / reminders** | 7.5% | 6.0% | Reminders that don't fire, or bills that can't be added manually |
| **Categorisation wrong / tedious** | 6.0% | 6.8% | Auto-categorisation errors frustrate users of bank-linked apps |

**The pattern differs by app.** Rocket Money's negative reviews are 63% about price. Monarch's and Copilot's are dominated by sync, bugs and support. Spendee's and Goodbudget's UK negatives are mostly bugs and data loss (38–42%).

Representative comments (shortened):

> "For something I'm paying $7 a month to use, glitches need to stop." (Goodbudget, 2★)
>
> "One day it asked me to relink every account, and since then there's a bunch of junk data and duplication." (Rocket Money, 1★)
>
> "Needs to either be much cheaper or be available for a one off cost." (Spendee, 4★)
>
> "The last update messed up my data and the UI is worse." (Spendee, 1★)

## 4. What people value (4–5★ reviews)

- **Awareness and control** (9.3% of positive reviews): "making me more aware of expenditure", "puts me in full visibility and control".
- **Debt payoff** (8.1%): seeing a date and progress is motivating.
- **Sharing with a partner** (7.7%): a strong positive driver, especially for YNAB and Goodbudget.
- **Charts and insights** (6.5%) and **savings goals / pots** (5.0%).

## 5. What people ask for (559 "I wish… / please add…" requests)

| Request | Mentions | In v1? |
|---|---:|---|
| Bank sync / more banks | 56 | Version 2 (see section 8) |
| Categories: custom, split, edit | 56 | Partly. Fixed UK categories plus spending limits now; custom categories in v1.1. |
| Recurring bills / reminders | 44 | **Yes** |
| **Payday / custom budget period** | 43 | **Yes**: weekly, fortnightly, 4-weekly, monthly on a date, last working day |
| Quick / manual entry | 31 | **Yes**: 3-tap entry, remembered account, "repeat today" |
| Debt: one-off payments, plan based on income | 26 | **Yes**: lump-sum payments and a suggestion based on your surplus |
| Charts / reports | 24 | **Yes** |
| Home-screen widget / Apple Watch | 23 | Widget **yes**; Watch later |
| Goals / savings | 22 | v1.1 |
| Export / backup / iPad / web | 22 | CSV export **yes**; iCloud sync v1.1 |
| Forecast / future balance | 21 | **Yes**: 5-week cash forecast and safe-to-spend |
| One-off price instead of subscription | 14 | Business model (section 7) |

> "For people that get paid weekly the weeks don't quite work out… we get paid every Friday so need Fri to Thu." (Bills Organizer, 5★)
>
> "Can you please make recurring expenses/salary show in the totals for future months so it has better forecasting." (Spending Tracker, 4★)
>
> "It would be nice to add a one-off payment to a debt when I come into some money." (Debt Payoff Planner, 3★)
>
> "I wish there was a function to manually input a bill not linked to my account transactions." (Snoop, 5★)

## 6. Search demand (Google Trends, UK)

Relative interest, where 100 = the peak for the busiest term:

| Year | "budgeting app" | "budget planner" | "money tracker" |
|---|---:|---:|---:|
| 2022 | 14.8 | 45.8 | 20.2 |
| 2023 | 14.8 | 46.8 | 21.4 |
| 2024 | 15.2 | 45.3 | 20.1 |
| 2025 | 19.2 | 42.5 | 23.2 |
| 2026 (to Nov) | **28.5** | 49.5 | **37.9** |

- **Seasonality:** January is the peak month, with a second bump in August/September. **Launch and market for January.**
- **Top related searches:** "best budgeting app (uk)", "free budgeting app", "emma", "snoop".
- **Fastest-rising related searches:** "ai budgeting app" (breakout), "monarch money", **"actual budget"** (an open-source app where your data stays with you), "rocket money".
- "Debt payoff" and "bill reminder" are low-volume searches in the UK. People search for the *app type* ("budgeting app"), so lead marketing with budgeting and show debt payoff as the standout feature.

## 7. Competitor landscape (UK App Store, Nov 2026)

| App | Ratings (UK) | Model | Strength | Weakness we can exploit |
|---|---:|---|---|---|
| Emma | 27k, 4.7★ | Bank-linked, subscription | Polished, popular | Subscription and cancellation complaints, sync drops |
| Snoop | 7.3k, 4.6★ | Bank-linked, freemium | Free, deal-finding | Can't add a bill manually; no payday budgeting |
| HyperJar | 32k, 4.8★ | Prepaid card with "jars" | Envelope budgeting | Requires moving money into their card |
| YNAB | 3k, 4.7★ | Subscription (~£12–15/month) | Proven method | Price rises, steep learning curve, flaky UK bank sync |
| Spending Tracker / Money Manager / Monefy | 1–5k | Manual, cheap | Fast and simple | Basic forecasting; no debt planning; ads |
| Debt Payoff Planner | 506, 4.7★ | Manual, freemium | Snowball/avalanche | US-centric; no budgeting or bills |

**Gap:** no single, well-made UK app combines **manual-first privacy + payday budgeting + bills/council tax + cash forecast + debt payoff**. Users currently stitch together 2–3 apps or a spreadsheet.

---

## 8. Recommendations

### MoSCoW prioritisation

*MoSCoW is a standard BA technique: **M**ust have, **S**hould have, **C**ould have, **W**on't have (this time). It forces a clear scope for a first release.*

| Priority | Feature | Evidence |
|---|---|---|
| **Must** | Accounts: current, savings, cash, credit cards, loans, mortgage, with balances | Core brief |
| **Must** | Fast manual entry plus a 30-second weekly **balance check-in** | Awareness praise; manual-entry fatigue |
| **Must** | Bills **and recurring income**, reminders, Direct Debit flag, **10-month council tax** | 44 requests; UK-specific |
| **Must** | **Payday-to-payday** periods (all common UK pay patterns) | 43 requests; UK forum complaints |
| **Must** | **Safe to spend until payday** and a **cash forecast** | 21 forecasting requests; the "left to pay" frustration on Monzo Community |
| **Must** | Charts: spending by category, in vs out, net worth over time | Core brief; 6.5% of positive reviews |
| **Must** | **Debt payoff planner**: avalanche/snowball, extra and one-off payments, debt-free date, interest saved | Core brief; 8.1% of positive reviews |
| **Must** | Private: on-device storage, Face ID lock, no account, CSV export | Data-loss and shutdown fears; privacy |
| **Must** | Clear "not financial advice" wording plus signposting to free debt help | Commercial and regulatory prudence |
| **Should** | Spending limits per category, with "left this period" | Category requests |
| **Should** | Home-screen widget | 23 requests |
| **Should** | Debt progress milestones | Motivation is a top praise theme |
| **Could (v1.1)** | iCloud sync and **partner sharing** | 7.7% of positive reviews mention partners |
| **Could (v1.1)** | Custom categories, split transactions, savings goals, CSV import of bank statements | Requests |
| **Won't (v1)** | Open banking connection, AI insights, Android | Cost, regulation and reliability risk; see the roadmap |

All **Must** and **Should** items are built in this version of the app.

### Pricing (business model)

The evidence strongly favours **no compulsory subscription**:

1. **Free core app** (all Must features) to build ratings and reach.
2. **One-off "Clarity Vaults Plus" unlock** (suggested £7.99–£14.99) for extras such as iCloud sync, partner sharing, unlimited spending limits and themes.
3. **Bundle with the PDF:** give PDF buyers Plus free or discounted via an App Store **offer code**. Since October 2025 offer codes work for one-time (non-consumable) in-app purchases, replacing the old promo codes, which stopped on 26 March 2026. You could print a code inside each PDF.
4. If a subscription is added later (e.g. for open banking, which has ongoing per-connection costs), keep it optional, priced low, with one-tap cancellation and no surprise renewals.

### Marketing angles (Instagram / TikTok)

- "Know what's **safe to spend until payday**" (UK-native framing).
- "**No bank login.** Your money data never leaves your phone."
- "See your **debt-free date**, and how much sooner £50 a month makes it." The planner makes good screen recordings.
- Post the example-data screens (built into the app) for clean, repeatable content.
- Peak campaigns: **January** ("new year money reset") and **late August** (back to school).
- ⚠️ All marketing should carry a short "budgeting tool, not financial advice" line.

---

## 9. Limitations

- Keyword tagging over-counts some themes (e.g. "price" also matches users *praising* a fair price). Read the percentages as relative sizes.
- Apple's feed caps each app at the 500 most recent reviews, and Emma's and Updraft's feeds were empty.
- Reddit could not be analysed (it blocks Anthropic's tools). UK forums were used instead.
- Google Trends figures are relative indices, not absolute search volumes.

## Sources

- Apple App Store public review feeds and iTunes Search API (UK and US storefronts), accessed 7 Nov 2026
- Google Trends, UK, 5-year window, accessed 7 Nov 2026
- [MoneySavingExpert forum: Budgeting apps / YNAB alternatives 2025](https://forums.moneysavingexpert.com/discussion/6570657/budgeting-apps-ynab-alternatives-for-2025)
- [MoneySavingExpert forum: Best budget and debt management apps](https://forums.moneysavingexpert.com/discussion/6029611/best-budget-and-debt-management-apps)
- [MoneySavingExpert forum: Money Dashboard apps closing down](https://forums.moneysavingexpert.com/discussion/6476542/money-dashboard-apps-closing-down)
- [Monzo Community: Salary Sorter and Bills Pots](https://community.monzo.com/t/introducing-salary-sorter-and-bills-pots/81016?page=40)
- [Monzo Community: Set start of month](https://community.monzo.com/t/set-start-of-month/1144?page=4)
- [Emma: custom budgeting periods that match your payday](https://emma-app.com/blog/new-in-emma-custom-budgeting-periods-that-match-your-payday)
- [Money To The Masses: Emma review](https://moneytothemasses.com/banking/emma-review-is-it-the-best-budgeting-app)
- [Trustpilot: Emma reviews](https://uk.trustpilot.com/review/emma-app.com)
- [Be Clever With Your Cash: Money Dashboard closing](https://becleverwithyourcash.com/money-dashboard-closing-what-are-the-alternatives/)
- [Household Money Saving: Moneyhub review (now closed)](https://www.householdmoneysaving.com/?p=16845)
- [NerdWallet: Best budget apps 2026](https://www.nerdwallet.com/finance/learn/best-budget-apps)
- [Skint Dad: Best budgeting apps UK 2026](https://skintdad.co.uk/best-budgeting-app-uk/)
- [Open Banking Tracker: Best open banking API providers 2026](https://www.openbankingtracker.com/blog/best-open-banking-api-providers-developers-2026)
- [Open Banking Tracker: Free and indie open banking APIs 2026](https://www.openbankingtracker.com/guides/free-open-banking-apis)
- [TrueLayer: FCA changes to 90-day reauthentication](https://support.truelayer.com/hc/en-us/articles/4418813282449-How-has-TrueLayer-implemented-the-FCA-s-changes-to-the-90-day-re-authentication-process)
- [MacRumors: Apple App Store developer updates, Oct 2025 (offer codes for all in-app purchase types)](https://www.macrumors.com/2025/10/29/apple-developer-app-store-updates/)
- [Apple Developer News: Enhancements to help you submit and market your apps](https://developer.apple.com/news/?id=gf6mgrs6)
- [Finexer: Best banking API providers in the UK](https://blog.finexer.com/7-best-banking-api-providers-in-the-uk-2025-guide/)
