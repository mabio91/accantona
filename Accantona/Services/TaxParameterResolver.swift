import Foundation

enum TaxParameterResolver {
    static func parameter(forFiscalYear fiscalYear: Int?, parameters: [TaxParameters]) -> TaxParameters? {
        let sorted = parameters.sorted { $0.year < $1.year }
        guard !sorted.isEmpty else { return nil }

        guard let fiscalYear else {
            return sorted.last
        }

        if let exact = sorted.first(where: { $0.year == fiscalYear }) {
            return exact
        }

        return sorted.last(where: { $0.year <= fiscalYear }) ?? sorted.first
    }

    static func parameter(for date: Date?, parameters: [TaxParameters]) -> TaxParameters? {
        parameter(forFiscalYear: fiscalYear(from: date), parameters: parameters)
    }

    static func parameter(for invoice: Invoice, parameters: [TaxParameters]) -> TaxParameters? {
        let fiscalYear = invoice.fiscalYear
            ?? fiscalYear(from: invoice.paidDate)
            ?? fiscalYear(from: invoice.expectedPaymentDate)
            ?? invoice.managementYear
        return parameter(forFiscalYear: fiscalYear, parameters: parameters)
    }

    static func parameter(forExpectedInvoice invoice: Invoice, parameters: [TaxParameters], fallback: TaxParameters?) -> TaxParameters? {
        parameter(for: invoice.expectedPaymentDate, parameters: parameters)
            ?? parameter(forFiscalYear: invoice.fiscalYear, parameters: parameters)
            ?? fallback
    }

    static func currentParameter(parameters: [TaxParameters], referenceDate: Date = .now) -> TaxParameters? {
        parameter(for: referenceDate, parameters: parameters)
    }

    private static func fiscalYear(from date: Date?) -> Int? {
        date.map { Calendar.current.component(.year, from: $0) }
    }
}
