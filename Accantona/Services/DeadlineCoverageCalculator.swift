import Foundation
import SwiftUI

enum DeadlineRisk {
    case covered
    case lowMargin
    case dependsOnFutureIncome
    case deficit

    var title: String {
        switch self {
        case .covered: "Coperto"
        case .lowMargin: "Margine basso"
        case .dependsOnFutureIncome: "Dipende da incassi futuri"
        case .deficit: "Deficit"
        }
    }

    var symbol: String {
        switch self {
        case .covered: "checkmark.seal.fill"
        case .lowMargin: "exclamationmark.triangle.fill"
        case .dependsOnFutureIncome: "clock.arrow.circlepath"
        case .deficit: "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .covered: AppColor.sage
        case .lowMargin: AppColor.amber
        case .dependsOnFutureIncome: AppColor.petrol
        case .deficit: AppColor.coral
        }
    }
}

struct DeadlineCoverageProjection: Identifiable {
    let deadline: TaxDeadline
    let grossAmount: Decimal
    let paidByF24: Decimal
    let remainingDue: Decimal
    let currentBalance: Decimal
    let recoverableReserves: Decimal
    let futureIncome: Decimal
    let futureReserves: Decimal
    let projectedBalance: Decimal
    let coveredAmount: Decimal
    let margin: Decimal
    let risk: DeadlineRisk
    let certaintyTitle: String
    let certaintySymbol: String
    let certaintyColor: Color

    var id: UUID { deadline.id }

    var coverageRatio: Decimal {
        guard grossAmount > 0 else { return 1 }
        return min(coveredAmount / grossAmount, 1)
    }
}

enum DeadlineCoverageCalculator {
    static func projection(
        for deadline: TaxDeadline,
        parameters: TaxParameters?,
        invoices: [Invoice],
        reserves: [ReserveEntry],
        taxPayments: [TaxPayment],
        snapshots: [TaxAccountSnapshot],
        movements: [TaxAccountMovement],
        startingBalance: Decimal? = nil,
        fromDateExclusive: Date? = nil
    ) -> DeadlineCoverageProjection {
        let currentBalance = startingBalance ?? TaxAccountLedger.balance(snapshots: snapshots, movements: movements)
        let paidByF24 = matchingPayments(for: deadline, payments: taxPayments)
            .reduce(Decimal(0)) { $0 + TaxPaymentAccounting.coveredAmount(for: $1) }
        let remainingDue = max(deadline.estimatedAmount - paidByF24, 0)

        let recoverable = reserves
            .filter { $0.status == .pending || $0.status == .partial || $0.status == .skipped }
            .filter { $0.date <= deadline.date && isAfterWindowStart($0.date, fromDateExclusive: fromDateExclusive) }
            .reduce(Decimal(0)) { $0 + max($1.prudentialAmount - $1.actualReservedAmount, 0) }

        let futureInvoices = invoices.filter { invoice in
            guard invoice.status != .paid, invoice.status != .cancelled else { return false }
            guard let expectedDate = invoice.expectedPaymentDate else { return false }
            return expectedDate <= deadline.date && isAfterWindowStart(expectedDate, fromDateExclusive: fromDateExclusive)
        }

        let futureIncome = futureInvoices.reduce(Decimal(0)) { $0 + $1.amount }
        let futureReserves = futureInvoices.reduce(Decimal(0)) { partial, invoice in
            guard let parameters else { return partial }
            return partial + TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: parameters).prudentialReserve
        }

        let balanceWithExistingRecoveries = currentBalance + recoverable
        let projectedBalance = balanceWithExistingRecoveries + futureReserves
        let coveredAmount = min(deadline.estimatedAmount, paidByF24 + max(projectedBalance, 0))
        let margin = projectedBalance - remainingDue
        let threshold = parameters?.minimumMarginThreshold ?? 250
        let risk = riskLevel(
            remainingDue: remainingDue,
            currentBalance: currentBalance,
            balanceWithExistingRecoveries: balanceWithExistingRecoveries,
            projectedBalance: projectedBalance,
            futureReserves: futureReserves,
            threshold: threshold
        )

        let certainty = certainty(for: deadline, paidByF24: paidByF24)

        return DeadlineCoverageProjection(
            deadline: deadline,
            grossAmount: deadline.estimatedAmount,
            paidByF24: paidByF24,
            remainingDue: remainingDue,
            currentBalance: currentBalance,
            recoverableReserves: recoverable,
            futureIncome: futureIncome,
            futureReserves: futureReserves,
            projectedBalance: projectedBalance,
            coveredAmount: coveredAmount,
            margin: margin,
            risk: risk,
            certaintyTitle: certainty.title,
            certaintySymbol: certainty.symbol,
            certaintyColor: certainty.color
        )
    }

    private static func isAfterWindowStart(_ date: Date, fromDateExclusive: Date?) -> Bool {
        guard let fromDateExclusive else { return true }
        return date > fromDateExclusive
    }

    private static func riskLevel(
        remainingDue: Decimal,
        currentBalance: Decimal,
        balanceWithExistingRecoveries: Decimal,
        projectedBalance: Decimal,
        futureReserves: Decimal,
        threshold: Decimal
    ) -> DeadlineRisk {
        if currentBalance >= remainingDue {
            return currentBalance - remainingDue < threshold ? .lowMargin : .covered
        }

        if balanceWithExistingRecoveries >= remainingDue {
            return balanceWithExistingRecoveries - remainingDue < threshold ? .lowMargin : .covered
        }

        if futureReserves > 0, projectedBalance >= remainingDue {
            return .dependsOnFutureIncome
        }

        return .deficit
    }

    private static func certainty(for deadline: TaxDeadline, paidByF24: Decimal) -> (title: String, symbol: String, color: Color) {
        if paidByF24 >= deadline.estimatedAmount, deadline.estimatedAmount > 0 {
            return ("Pagato", "checkmark.circle.fill", AppColor.sage)
        }

        if deadline.certainty == .confirmed {
            return ("Dato certo", "checkmark.seal.fill", AppColor.sage)
        }

        if paidByF24 > 0 {
            return ("Da F24", "doc.plaintext.fill", AppColor.petrol)
        }

        return ("Stimato", "function", AppColor.amber)
    }

    private static func matchingPayments(for deadline: TaxDeadline, payments: [TaxPayment]) -> [TaxPayment] {
        payments.filter { payment in
            paymentMatchesDeadlineKind(payment, deadline: deadline)
            && paymentMatchesDeadlineYear(payment, deadline: deadline)
            && payment.paymentDate <= deadline.date
        }
    }

    private static func paymentMatchesDeadlineKind(_ payment: TaxPayment, deadline: TaxDeadline) -> Bool {
        let title = deadline.title.lowercased()
        switch payment.type {
        case .balance, .firstAdvance:
            return title.contains("saldo") || title.contains("primo") || title.contains("giugno")
        case .secondAdvance:
            return title.contains("secondo") || title.contains("novembre")
        case .stampDuty:
            return title.contains("bollo")
        case .other:
            return false
        }
    }

    private static func paymentMatchesDeadlineYear(_ payment: TaxPayment, deadline: TaxDeadline) -> Bool {
        let paymentCalendarYear = Calendar.current.component(.year, from: payment.paymentDate)
        let deadlineCalendarYear = Calendar.current.component(.year, from: deadline.date)
        return payment.taxYear == deadline.taxYear || paymentCalendarYear == deadlineCalendarYear
    }
}
