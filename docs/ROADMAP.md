# Clarity Vaults: roadmap

## v1.0 (this build)

Everything in the **Must** and **Should** rows of `market-research.md`:
manual-first accounts (including mortgage), fast entry, weekly balance check-in, bills and recurring income
with reminders (including 10-month council tax), payday-to-payday periods, safe to spend, 5-week cash forecast,
category spending limits, insights charts, debt payoff planner (avalanche/snowball, extra and one-off payments,
income-based suggestion), home-screen widget, Face ID lock, CSV export, example data,
**backup to iCloud Drive / Files with restore and undo**.

## v1.1: retention and sharing (≈ 1–3 months after launch)

| Feature | Why | Notes |
|---|---|---|
| iCloud sync between devices | iPad requests; v1.0 already has manual backup/restore | Models already have defaults on every property, so SwiftData + CloudKit can be switched on (`cloudKitDatabase: .automatic`) without migration. Needs an iCloud container in the Apple Developer account. |
| Partner / household sharing | 7.7% of positive reviews mention partners | CloudKit sharing (`CKShare`). Good candidate for the paid "Plus" unlock. |
| Custom categories and split transactions | Top-2 request theme | Move categories from an enum to a model. |
| Savings goals / sinking funds | 22 requests; annual bills | E.g. "car service £400 by March": monthly amount needed. |
| CSV import of bank statements | Bridge to automation without open banking | Most UK banks export CSV; map columns once per bank. |
| Bank-holiday aware paydays | UK accuracy | GOV.UK publishes bank holidays as JSON. |
| Apple Watch quick-add, Lock Screen widget | Requests | |

## v2: connected accounts (open banking)

**What it is:** with the customer's consent, read balances and transactions directly from their bank via the UK
Open Banking APIs, so they don't type them in.

**Regulation (important):** reading bank data is a regulated activity, an **Account Information Service (AIS)**.
You either need your own FCA authorisation as an AISP (slow and costly for a sole trader) or, far more practically,
use a **licensed aggregator** and operate under their permissions as their agent or customer.

**Shortlist to request quotes from** (none publish production pricing as of Nov 2026):

| Provider | Notes |
|---|---|
| TrueLayer | Strong UK coverage; sales-led pricing |
| Yapily | FCA-regulated (Yapily Connect); sandbox available; tiered pricing |
| Enable Banking | Cheapest option for prototyping; quote-based since April 2026 |
| GoCardless Bank Account Data (ex-Nordigen) | Reported closed to new sign-ups; check before planning around it |

**What v2 would need beyond the app:**
1. **A small backend server.** Provider API secrets must never sit inside an iPhone app. This changes the privacy story ("on-device only"), so be upfront about it.
2. **Consent renewal every 90 days.** The FCA removed bank *re-authentication*, but customers must still re-confirm consent with the app every 90 days.
3. **ICO registration** (data protection fee), a privacy policy and a DPIA (Data Protection Impact Assessment), because you'd be processing financial data.
4. **Ongoing cost per connected user**, which justifies an optional low-cost subscription for the connected tier only.
5. **Keep manual mode** as the default, free option. The research shows bank sync is the third-biggest complaint even for the market leaders, so never make it the only way the app works.

**Possible v2 extras:** AI spending summaries ("ai budgeting app" is the fastest-rising related search). These must
be private by design: send only anonymised category totals, and make it opt-in.

## Before App Store submission (checklist)

- [ ] Apple Developer Program membership (£79/year) and Team ID set in `project.yml`
- [ ] App icon (1024×1024) in `Assets.xcassets/AppIcon`, plus final brand colours in `Theme.swift`
- [ ] Privacy policy URL (even with no data collection, Apple requires one); App Privacy label: "Data Not Collected"
- [ ] Screenshots: use **Settings → Load example data**
- [ ] Test on a real iPhone: notifications, Face ID, widget
- [ ] App Store description includes "budgeting tool, not financial advice" wording
- [ ] Decide pricing (see market research, section 8)
