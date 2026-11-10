# Clarity Vaults (iOS app)

A private, manual-first money app for the Clarity Vaults finance guides. It shows what's **safe to spend until
payday**, reminds you about **bills**, charts **where your money goes**, and forecasts your **debt-free date**.

The feature set comes from the research in [`../docs/market-research.md`](../docs/market-research.md)
(6,646 App Store reviews, Google Trends and UK forums). Future versions are in [`../docs/ROADMAP.md`](../docs/ROADMAP.md).

## Features

| Area | What it does |
|---|---|
| **Home** | Safe to spend until payday (with breakdown), weekly check-in prompt, this pay period's in/out and spending limits, 5-week cash forecast with overdraft warning, upcoming bills, net position, debt-free date, recent activity |
| **Activity** | Money in / out / transfers; 3-tap entry; search and filter; swipe to delete or "repeat today" |
| **Bills & income** | Weekly to yearly, plus **10-month council tax**; Direct Debit flag; reminders N days before and on the day; mark paid (moves to the next due date and optionally records the payment); recurring income such as salary |
| **Accounts** | Current, savings, cash, credit card, loan, mortgage. APR, minimum payment, credit limit, overdraft. Balance history chart. **Update all balances** check-in. Payoff progress per debt. |
| **Insights** | Spending by category (donut, any pay period); money in vs out (last 6 pay periods, with average surplus); net worth over time; category spending limits |
| **Payoff planner** | Avalanche or snowball; extra monthly payment; one-off lump sum; suggestion based on your surplus; debt-free date; interest saved vs minimums only; balance chart by debt; payoff order; warnings for minimums below interest and 0% promotional rates |
| **Settings** | Payday (monthly on a date with weekend → Friday, last working day, weekly, fortnightly, 4-weekly); safety buffer; reminder time; Face ID lock; CSV export; example data; erase all |
| **Backup** | **Back up now** saves one file to iCloud Drive (or anywhere in Files). **Restore from backup** shows what's in the file and asks before replacing anything. It keeps a safety copy so the restore can be **undone**. Monthly reminder on Home; restore is also offered during first-time setup for new phones. |
| **Widget** | Small/medium home-screen widget: safe to spend, days to payday, next bill |

**Privacy:** all data is stored on the device with SwiftData. No account, no network calls, no analytics. Backups go
wherever the user saves them (normally their own iCloud Drive), never to us.

## Requirements

- A Mac with **Xcode 15.3 or later** (Xcode 16 recommended)
- iOS **17.0+** (iPhone)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project

## Build and run

```bash
brew install xcodegen          # once
cd ClarityVaults
xcodegen generate              # creates ClarityVaults.xcodeproj from project.yml
open ClarityVaults.xcodeproj
```

In Xcode, choose an iPhone simulator and press **⌘R**. On first launch, choose **Explore with example data** to see
every screen populated. Press **⌘U** to run the unit tests.

**To run on your own iPhone or use the widget on a device:** set `DEVELOPMENT_TEAM` in `project.yml` to your
Apple Developer Team ID, run `xcodegen generate` again, and make sure the App Group
`group.com.clarityvaults.app` is enabled for both the app and widget identifiers (Xcode's
*Signing & Capabilities* tab can do this automatically).

## Project structure

```
ClarityVaults/
├── project.yml                 XcodeGen project definition (app, widget, tests)
├── Config/                     Entitlements (App Group) and widget Info.plist
├── ClarityVaults/
│   ├── App/                    App entry, tab bar, Face ID lock screen
│   ├── Theme/Theme.swift       ALL colours, radii and card styles: edit here to match the brand
│   ├── Models/                 SwiftData models (Account, LedgerEntry, Bill, CategoryBudget, BalanceSnapshot) and enums
│   ├── Logic/                  Pure, unit-tested calculations
│   │   ├── PaySchedule.swift      payday-to-payday periods
│   │   ├── BillScheduler.swift    recurring due dates (month-end safe, council tax 10-monthly)
│   │   ├── CashForecast.swift     safe to spend and cash forecast
│   │   ├── DebtForecaster.swift   avalanche / snowball simulation
│   │   ├── BalanceEngine.swift    how entries change balances (cards/loans vs assets)
│   │   ├── Analytics.swift        category totals, in vs out, net worth history
│   │   ├── BackupFormat.swift     versioned JSON backup file format
│   │   └── Formatting.swift       £ and en-GB date formatting
│   ├── Services/               Settings, notifications, Face ID, widget bridge, CSV, example data
│   └── Views/                  SwiftUI screens by tab
├── ClarityWidget/              WidgetKit extension
├── Shared/                     Code used by both app and widget
└── ClarityVaultsTests/         Unit tests (bill dates, pay periods, debt maths, forecasts, balances)
```

## How the calculations work

- **Safe to spend** = current + cash balances − bills due before next payday (including overdue ones) + recurring
  income due before payday − safety buffer. Bills paid from a credit card aren't subtracted.
- **Cash forecast** = today's spending money moved forward by scheduled bills and income only (day-to-day spending
  isn't predicted).
- **Debt payoff** = monthly simulation: interest (APR ÷ 12) is added, minimums are paid, and the extra goes to the target
  debt. Cleared debts' minimums roll over. Plans that never clear are detected and stop early. Assumes fixed minimums
  and rates, so the app tells users this and links to MoneyHelper / StepChange.
- **Balances:** for credit cards, loans and mortgages the balance is *what you owe* (a positive number). Spending on a card
  increases it; a transfer from a current account to the card reduces both.

## Testing status

- The 27 logic unit tests pass (including backup save/read round-trip and version checks). They were compiled and run with Swift 6.0.3 (Swift 5 language mode) on Linux against
  the same source files, with the UI-only types stubbed out.
- The SwiftUI screens, widget, notifications and Face ID can only be built on macOS. **Do a first build in Xcode and
  test on a device** before release.

## Disclaimer

Clarity Vaults is a budgeting tool, not financial advice. Forecasts are estimates based on user-entered figures.

## Backup file format

A backup is one pretty-printed JSON file (`Clarity Vaults backup YYYY-MM-DD.json`) containing a `formatVersion`,
settings, accounts with balance history, activity, bills and spending limits. It's defined in
`Logic/BackupFormat.swift`. If you ever change the data model, add the new fields as optional, bump
`BackupFile.currentVersion`, and keep reading older versions so customers' old backups still restore.
