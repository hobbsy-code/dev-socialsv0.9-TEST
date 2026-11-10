import XCTest
@testable import ClarityVaults

/// Unit tests for the pure calculation logic. Run with ⌘U in Xcode.
final class BillSchedulerTests: XCTestCase {
    let cal = Fmt.calendar

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testMonthlyKeepsAnchorDayAfterShortMonth() {
        let jan31 = date(2027, 1, 31)
        let feb = BillScheduler.nextDate(after: jan31, frequency: .monthly, anchorDay: 31)
        XCTAssertEqual(feb, date(2027, 2, 28))
        let mar = BillScheduler.nextDate(after: feb, frequency: .monthly, anchorDay: 31)
        XCTAssertEqual(mar, date(2027, 3, 31), "should snap back to the 31st, not drift to the 28th")
    }

    func testLeapYearFebruary() {
        XCTAssertEqual(BillScheduler.nextDate(after: date(2028, 1, 30), frequency: .monthly, anchorDay: 30), date(2028, 2, 29))
    }

    func testCouncilTaxSkipsFebruaryAndMarch() {
        let jan = date(2027, 1, 1)
        XCTAssertEqual(BillScheduler.nextDate(after: jan, frequency: .councilTax10, anchorDay: 1), date(2027, 4, 1))
        XCTAssertEqual(BillScheduler.nextDate(after: date(2027, 4, 1), frequency: .councilTax10, anchorDay: 1), date(2027, 5, 1))
        let dates = BillScheduler.occurrences(firstDue: date(2027, 4, 1), frequency: .councilTax10, anchorDay: 1, before: date(2028, 4, 1))
        XCTAssertEqual(dates.count, 10, "10 instalments a year")
    }

    func testWeeklyAndFourWeekly() {
        XCTAssertEqual(BillScheduler.nextDate(after: date(2027, 3, 1), frequency: .weekly, anchorDay: 1), date(2027, 3, 8))
        XCTAssertEqual(BillScheduler.nextDate(after: date(2027, 3, 1), frequency: .fourWeekly, anchorDay: 1), date(2027, 3, 29))
    }

    func testQuarterlyAndAnnual() {
        XCTAssertEqual(BillScheduler.nextDate(after: date(2027, 11, 30), frequency: .quarterly, anchorDay: 30), date(2028, 2, 29))
        XCTAssertEqual(BillScheduler.nextDate(after: date(2027, 6, 15), frequency: .annually, anchorDay: 15), date(2028, 6, 15))
    }
}

final class PayScheduleTests: XCTestCase {
    let cal = Fmt.calendar
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

    func testMonthlyPeriodMovesWeekendPaydayToFriday() {
        // 28 Feb 2027 is a Sunday, so payday is Friday 26 Feb.
        var s = PaySchedule(); s.frequency = .monthlyOnDay; s.dayOfMonth = 28; s.moveWeekendToFriday = true
        let p = s.period(containing: date(2027, 3, 10))
        XCTAssertEqual(p.start, date(2027, 2, 26))
        XCTAssertEqual(p.end, date(2027, 3, 26)) // 28 Mar 2027 is a Sunday as well
    }

    func testBeforePaydayBelongsToPreviousPeriod() {
        var s = PaySchedule(); s.dayOfMonth = 15; s.moveWeekendToFriday = false
        let p = s.period(containing: date(2027, 6, 10))
        XCTAssertEqual(p.start, date(2027, 5, 15))
        XCTAssertEqual(p.end, date(2027, 6, 15))
    }

    func testLastWorkingDay() {
        var s = PaySchedule(); s.frequency = .lastWorkingDay
        // 31 Jul 2027 is a Saturday, so payday is Friday 30 Jul.
        let p = s.period(containing: date(2027, 8, 5))
        XCTAssertEqual(p.start, date(2027, 7, 30))
        XCTAssertEqual(p.end, date(2027, 8, 31))
    }

    func testFourWeeklyFromAnchor() {
        var s = PaySchedule(); s.frequency = .fourWeekly; s.anchorDate = date(2027, 1, 8)
        let p = s.period(containing: date(2027, 3, 10))
        XCTAssertEqual(p.start, date(2027, 3, 5))
        XCTAssertEqual(p.end, date(2027, 4, 2))
        // Works for dates before the anchor too
        let earlier = s.period(containing: date(2026, 12, 20))
        XCTAssertEqual(earlier.start, date(2026, 12, 11))
    }

    func testRecentPeriodsAreContiguous() {
        var s = PaySchedule(); s.dayOfMonth = 1; s.moveWeekendToFriday = false
        let periods = s.recentPeriods(6, endingAt: date(2027, 6, 10))
        XCTAssertEqual(periods.count, 6)
        for (a, b) in zip(periods, periods.dropFirst()) { XCTAssertEqual(a.end, b.start) }
    }
}

final class DebtForecasterTests: XCTestCase {
    func debt(_ name: String, _ balance: Double, _ apr: Double, _ min: Double) -> DebtInput {
        DebtInput(id: UUID(), name: name, balance: balance, apr: apr, minimumPayment: min)
    }

    func testZeroInterestPaysOffExactly() {
        let plan = DebtForecaster.plan(debts: [debt("A", 1_200, 0, 100)], monthlyBudget: 100, strategy: .avalanche)
        XCTAssertEqual(plan.months, 12)
        XCTAssertEqual(plan.totalInterest, 0, accuracy: 0.001)
    }

    func testKnownAmortisation() {
        // £1,000 at 12% APR paying £100/month clears in 11 months with ~£59 interest.
        let plan = DebtForecaster.plan(debts: [debt("A", 1_000, 12, 100)], monthlyBudget: 100, strategy: .avalanche)
        XCTAssertEqual(plan.months, 11)
        XCTAssertEqual(plan.totalInterest, 58.98, accuracy: 0.05)
    }

    func testAvalancheCostsNoMoreThanSnowball() {
        let debts = [debt("Card", 3_000, 24.9, 90), debt("Store", 600, 29.9, 25), debt("Loan", 6_000, 7.9, 180)]
        let budget = DebtForecaster.totalMinimums(debts) + 200
        let avalanche = DebtForecaster.plan(debts: debts, monthlyBudget: budget, strategy: .avalanche)
        let snowball = DebtForecaster.plan(debts: debts, monthlyBudget: budget, strategy: .snowball)
        XCTAssertNotNil(avalanche.months)
        XCTAssertLessThanOrEqual(avalanche.totalInterest, snowball.totalInterest + 0.01)
    }

    func testExtraPaymentShortensPlan() {
        let debts = [debt("Card", 3_000, 24.9, 90)]
        let base = DebtForecaster.plan(debts: debts, monthlyBudget: 90, strategy: .avalanche)
        let extra = DebtForecaster.plan(debts: debts, monthlyBudget: 190, strategy: .avalanche)
        XCTAssertLessThan(extra.months!, base.months!)
        XCTAssertLessThan(extra.totalInterest, base.totalInterest)
    }

    func testLumpSumHelps() {
        let debts = [debt("Card", 3_000, 24.9, 150)]
        let base = DebtForecaster.plan(debts: debts, monthlyBudget: 150, strategy: .avalanche)
        let lump = DebtForecaster.plan(debts: debts, monthlyBudget: 150, strategy: .avalanche, lumpSum: 1_000, lumpSumMonth: 2)
        XCTAssertLessThan(lump.months!, base.months!)
    }

    func testNeverPaysOffWhenPaymentBelowInterest() {
        // £10,000 at 30% = £250/month interest; £200 never clears it.
        let plan = DebtForecaster.plan(debts: [debt("A", 10_000, 30, 200)], monthlyBudget: 200, strategy: .avalanche)
        XCTAssertNil(plan.months)
        XCTAssertLessThan(plan.points.count, 30, "should stop early once the balance is clearly growing")
    }

    func testOrdering() {
        let a = debt("Big low", 5_000, 5, 50), b = debt("Small high", 300, 30, 10), c = debt("Mid", 1_000, 20, 20)
        XCTAssertEqual(DebtForecaster.ordered([a, b, c], strategy: .avalanche).map(\.name), ["Small high", "Mid", "Big low"])
        XCTAssertEqual(DebtForecaster.ordered([a, b, c], strategy: .snowball).map(\.name), ["Small high", "Mid", "Big low"])
        let d = debt("Small low", 200, 3, 10)
        XCTAssertEqual(DebtForecaster.ordered([a, c, d], strategy: .snowball).first?.name, "Small low")
        XCTAssertEqual(DebtForecaster.ordered([a, c, d], strategy: .avalanche).first?.name, "Mid")
    }
}

final class CashForecastTests: XCTestCase {
    let cal = Fmt.calendar
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

    func flow(_ amount: Double, due: Date, income: Bool = false, spending: Bool = true) -> ScheduledFlow {
        ScheduledFlow(name: "x", amount: amount, isIncome: income, nextDue: due, frequency: .monthly,
                      anchorDay: cal.component(.day, from: due), affectsSpendingMoney: spending)
    }

    func testSafeToSpendSubtractsBillsBeforePaydayOnly() {
        let now = date(2027, 3, 10), payday = date(2027, 3, 26)
        let flows = [flow(800, due: date(2027, 3, 15)), flow(50, due: date(2027, 3, 28)), flow(30, due: date(2027, 3, 20), spending: false)]
        let s = CashForecast.safeToSpend(spendingMoney: 1_500, flows: flows, nextPayday: payday, buffer: 100, now: now)
        XCTAssertEqual(s.billsBeforePayday, 800)
        XCTAssertEqual(s.amount, 600)
        XCTAssertEqual(s.daysUntilPayday, 16)
    }

    func testOverdueBillsStillCount() {
        let now = date(2027, 3, 10)
        let s = CashForecast.safeToSpend(spendingMoney: 500, flows: [flow(40, due: date(2027, 3, 5))],
                                         nextPayday: date(2027, 3, 26), buffer: 0, now: now)
        XCTAssertEqual(s.billsBeforePayday, 40)
    }

    func testProjectionAppliesIncomeAndBills() {
        let now = date(2027, 3, 10)
        let flows = [flow(2_000, due: date(2027, 3, 26), income: true), flow(800, due: date(2027, 3, 15))]
        let points = CashForecast.project(startBalance: 1_000, flows: flows, days: 20, now: now)
        XCTAssertEqual(points.first?.balance, 1_000)
        XCTAssertEqual(points.first { $0.date == date(2027, 3, 15) }?.balance, 200)
        XCTAssertEqual(points.last?.balance, 2_200)
        XCTAssertEqual(CashForecast.lowestPoint(points)?.balance, 200)
    }
}

final class BalanceEngineTests: XCTestCase {
    func testDirections() {
        let cur = UUID(), card = UUID()
        // Spending on a card increases what you owe
        XCTAssertEqual(BalanceEngine.effects(amount: 20, kind: .expense, sourceID: card, sourceKind: .creditCard, destinationID: nil, destinationKind: nil),
                       [.init(accountID: card, delta: 20)])
        // Paying the card from a current account reduces both
        XCTAssertEqual(BalanceEngine.effects(amount: 100, kind: .transfer, sourceID: cur, sourceKind: .current, destinationID: card, destinationKind: .creditCard),
                       [.init(accountID: cur, delta: -100), .init(accountID: card, delta: -100)])
        // Income into a current account increases it
        XCTAssertEqual(BalanceEngine.effects(amount: 50, kind: .income, sourceID: cur, sourceKind: .current, destinationID: nil, destinationKind: nil),
                       [.init(accountID: cur, delta: 50)])
    }

    func testParseAmount() {
        XCTAssertEqual(Fmt.parseAmount("£1,250.50"), 1_250.50)
        XCTAssertEqual(Fmt.parseAmount("-120"), -120)
        XCTAssertNil(Fmt.parseAmount("abc"))
        XCTAssertNil(Fmt.parseAmount(""))
    }
}

final class CategoryColourTests: XCTestCase {
    func testOutgoingCategoriesHaveDistinctColours() {
        let hexes = SpendCategory.expenseCases.map(\.colourHex)
        XCTAssertEqual(Set(hexes).count, hexes.count, "each outgoing category needs its own chart colour")
    }
}

final class BackupFormatTests: XCTestCase {
    func sample() -> BackupFile {
        let acc = UUID(), bill = UUID()
        let created = Date(timeIntervalSince1970: 1_790_000_000) // whole seconds survive ISO 8601
        return BackupFile(
            createdAt: created, appVersion: "1.0",
            settings: .init(paySchedule: PaySchedule(frequency: .fourWeekly, dayOfMonth: 28, anchorDate: created, moveWeekendToFriday: true),
                            safeToSpendBuffer: 50, reminderHour: 9, payoffStrategy: "snowball", payoffExtra: 75),
            accounts: [.init(id: acc, name: "Visa", kind: "creditCard", balance: 2_850, apr: 24.9, minimumPayment: 85,
                             creditLimit: 4_000, overdraftLimit: 0, includeInPayoff: true, startingBalance: 3_400, sortOrder: 0,
                             createdAt: created, balanceUpdatedAt: created,
                             snapshots: [.init(date: created, balance: 3_400), .init(date: created.addingTimeInterval(86_400), balance: 2_850)])],
            entries: [.init(id: UUID(), amount: 12.5, kind: "expense", category: "groceries", note: "Milk, \"bread\" & eggs",
                            date: created, accountID: acc, transferAccountID: nil, billID: bill)],
            bills: [.init(id: bill, name: "Council tax", amount: 165, category: "councilTax", frequency: "councilTax10",
                          nextDueDate: created, anchorDay: 1, reminderDaysBefore: 2, remindOnDueDay: true, isDirectDebit: true,
                          isIncome: false, accountID: acc, isActive: true, lastPaidDate: nil, notes: "", createdAt: created)],
            budgets: [.init(category: "groceries", limit: 320)])
    }

    func testRoundTripIsLossless() throws {
        let original = sample()
        let restored = try BackupFile.read(original.encoded())
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.summary, "1 account, 1 bill, 1 entry")
    }

    func testRejectsFilesThatAreNotBackups() {
        XCTAssertThrowsError(try BackupFile.read(Data("{\"hello\": 1}".utf8))) { XCTAssertEqual($0 as? BackupFile.ReadError, .notABackup) }
        XCTAssertThrowsError(try BackupFile.read(Data("not json".utf8))) { XCTAssertEqual($0 as? BackupFile.ReadError, .notABackup) }
    }

    func testRejectsNewerFormatWithClearMessage() throws {
        var newer = sample()
        newer.formatVersion = BackupFile.currentVersion + 1
        XCTAssertThrowsError(try BackupFile.read(newer.encoded())) {
            XCTAssertEqual($0 as? BackupFile.ReadError, .newerVersion(BackupFile.currentVersion + 1))
        }
    }

    func testFilenameUsesDate() {
        XCTAssertTrue(sample().suggestedFilename.hasPrefix("Clarity Vaults backup 2026-"))
    }
}
