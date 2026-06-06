import Foundation

enum MoneyFormatting {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "it_IT")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = Locale(identifier: "it_IT")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    static func money(_ value: Decimal) -> String {
        currency.string(from: value as NSDecimalNumber) ?? "\(value) EUR"
    }

    static func percentage(_ value: Decimal) -> String {
        percent.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    static func decimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "it_IT")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    static func parseDecimal(_ text: String) -> Decimal {
        parseDecimalOrNil(text) ?? 0
    }

    static func parseDecimalOrNil(_ text: String) -> Decimal? {
        let compact = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !compact.isEmpty else { return nil }
        let normalized: String
        if compact.contains(",") {
            normalized = compact
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = compact
        }
        let decimalPattern = #"^[+-]?([0-9]+(\.[0-9]+)?|\.[0-9]+)$"#
        guard normalized.range(of: decimalPattern, options: .regularExpression) != nil else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}

extension Decimal {
    var roundedMoney: Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .bankers)
        return result
    }
}
