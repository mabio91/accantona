import Foundation

struct AnnualTaxComparison {
    let taxPeriod: Int
    let registeredIncome: Decimal
    let calculatedReserves: Decimal
    let f24TaxPaid: Decimal
    let f24InpsPaid: Decimal
    let declaredRevenues: Decimal
    let declaredTaxAndInpsDue: Decimal
    let declaredTaxAndInpsBalance: Decimal
    let incomeDelta: Decimal
    let reserveVsDeclarationDelta: Decimal
    let f24VsDeclarationDelta: Decimal
}

enum TaxReturnCalculator {
    static func comparison(
        for summary: TaxReturnSummary,
        invoices: [Invoice],
        reserves: [ReserveEntry],
        payments: [TaxPayment]
    ) -> AnnualTaxComparison {
        let period = summary.taxPeriod
        let registeredIncome = invoices
            .filter { invoiceBelongsToPeriod($0, period: period) }
            .reduce(Decimal(0)) { $0 + $1.amount }
            .roundedMoney

        let invoicesById = Dictionary(uniqueKeysWithValues: invoices.map { ($0.id, $0) })
        let calculatedReserves = reserves
            .filter { reserveBelongsToPeriod($0, period: period, invoicesById: invoicesById) }
            .reduce(Decimal(0)) { $0 + $1.prudentialAmount }
            .roundedMoney

        let f24ForPeriod = payments.filter { $0.taxYear == period }
        let f24TaxPaid = f24ForPeriod
            .filter { $0.section == .erario }
            .reduce(Decimal(0)) { $0 + TaxPaymentAccounting.coveredAmount(for: $1) }
            .roundedMoney
        let f24InpsPaid = f24ForPeriod
            .filter { $0.section == .inps }
            .reduce(Decimal(0)) { $0 + TaxPaymentAccounting.coveredAmount(for: $1) }
            .roundedMoney

        let declaredDue = (summary.substituteTaxDue + summary.inpsDue).roundedMoney
        let declaredBalance = (summary.substituteTaxBalanceOrCredit + summary.inpsBalanceOrCredit).roundedMoney

        return AnnualTaxComparison(
            taxPeriod: period,
            registeredIncome: registeredIncome,
            calculatedReserves: calculatedReserves,
            f24TaxPaid: f24TaxPaid,
            f24InpsPaid: f24InpsPaid,
            declaredRevenues: summary.revenues.roundedMoney,
            declaredTaxAndInpsDue: declaredDue,
            declaredTaxAndInpsBalance: declaredBalance,
            incomeDelta: (registeredIncome - summary.revenues).roundedMoney,
            reserveVsDeclarationDelta: (calculatedReserves - declaredDue).roundedMoney,
            f24VsDeclarationDelta: ((f24TaxPaid + f24InpsPaid) - declaredDue).roundedMoney
        )
    }

    static func derivedGrossIncome(revenues: Decimal, profitabilityCoefficient: Decimal) -> Decimal {
        (revenues * profitabilityCoefficient).roundedMoney
    }

    static func derivedTaxableIncome(grossIncome: Decimal, deductedContributions: Decimal) -> Decimal {
        max(grossIncome - deductedContributions, 0).roundedMoney
    }

    private static func invoiceBelongsToPeriod(_ invoice: Invoice, period: Int) -> Bool {
        if let fiscalYear = invoice.fiscalYear {
            return fiscalYear == period
        }
        guard invoice.status == .paid, let paidDate = invoice.paidDate else {
            return false
        }
        return Calendar.current.component(.year, from: paidDate) == period
    }

    private static func reserveBelongsToPeriod(_ reserve: ReserveEntry, period: Int, invoicesById: [UUID: Invoice]) -> Bool {
        if let invoiceId = reserve.invoiceId, let invoice = invoicesById[invoiceId] {
            if let fiscalYear = invoice.fiscalYear {
                return fiscalYear == period
            }
            if let paidDate = invoice.paidDate {
                return Calendar.current.component(.year, from: paidDate) == period
            }
        }

        return Calendar.current.component(.year, from: reserve.date) == period
    }
}
