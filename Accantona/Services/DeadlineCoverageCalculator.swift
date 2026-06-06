import Foundation
import SwiftUI

enum DeadlineRisk: Equatable {
    case covered
    case lowMargin
    case dependsOnRecovery
    case dependsOnFutureIncome
    case deficit

    var title: String {
        switch self {
        case .covered: "Coperta"
        case .lowMargin: "Coperta ma stretta"
        case .dependsOnRecovery: "Recuperi necessari"
        case .dependsOnFutureIncome: "Dipende da incassi futuri"
        case .deficit: "Da coprire"
        }
    }

    var symbol: String {
        switch self {
        case .covered: "checkmark.seal.fill"
        case .lowMargin: "exclamationmark.triangle.fill"
        case .dependsOnRecovery: "arrow.counterclockwise.circle.fill"
        case .dependsOnFutureIncome: "clock.arrow.circlepath"
        case .deficit: "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .covered: AppColor.sage
        case .lowMargin: AppColor.amber
        case .dependsOnRecovery: AppColor.amber
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
        parameterCatalog: [TaxParameters] = [],
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
            guard let invoiceParameters = TaxParameterResolver.parameter(
                forExpectedInvoice: invoice,
                parameters: parameterCatalog,
                fallback: parameters
            ) else { return partial }
            return partial + TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: invoiceParameters).prudentialReserve
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
        if remainingDue <= 0 {
            return .covered
        }

        if currentBalance >= remainingDue {
            return currentBalance - remainingDue < threshold ? .lowMargin : .covered
        }

        if balanceWithExistingRecoveries >= remainingDue {
            return .dependsOnRecovery
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
            if let deadlineId = payment.deadlineId {
                return deadlineId == deadline.id
            }

            return paymentMatchesDeadlineKind(payment, deadline: deadline)
                && payment.paymentDate <= deadline.date
        }
    }

    private static func paymentMatchesDeadlineKind(_ payment: TaxPayment, deadline: TaxDeadline) -> Bool {
        let kind = DeadlineKind(deadline: deadline)

        switch payment.type {
        case .balance:
            return payment.taxYear == deadline.taxYear && kind.includesBalance
        case .firstAdvance:
            guard kind.includesFirstAdvance else { return false }
            if payment.taxYear == deadline.taxYear + 1 {
                return true
            }
            return payment.taxYear == deadline.taxYear
        case .secondAdvance:
            return payment.taxYear == deadline.taxYear && kind.includesSecondAdvance
        case .stampDuty:
            return payment.taxYear == deadline.taxYear && kind.includesStampDuty
        case .other:
            return false
        }
    }

    private struct DeadlineKind {
        let includesBalance: Bool
        let includesFirstAdvance: Bool
        let includesSecondAdvance: Bool
        let includesStampDuty: Bool

        init(deadline: TaxDeadline) {
            let title = deadline.title.lowercased()
            let month = Calendar.current.component(.month, from: deadline.date)
            let mentionsBalance = title.contains("saldo")
            let mentionsFirstAdvance = title.contains("primo")
            let mentionsSecondAdvance = title.contains("secondo")
            let mentionsStampDuty = title.contains("bollo")
            let mentionsJune = title.contains("giugno") || month == 6
            let mentionsNovember = title.contains("novembre") || month == 11
            let isGenericJuneDeadline = mentionsJune && !mentionsBalance && !mentionsFirstAdvance && !mentionsStampDuty

            includesBalance = mentionsBalance || isGenericJuneDeadline
            includesFirstAdvance = mentionsFirstAdvance || isGenericJuneDeadline
            includesSecondAdvance = (mentionsSecondAdvance || mentionsNovember) && !mentionsStampDuty
            includesStampDuty = mentionsStampDuty
        }
    }
}
