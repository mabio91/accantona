import Foundation

enum TaxParameterSanitizer {
    @discardableResult
    static func normalize(_ parameter: TaxParameters) -> Bool {
        var changed = false

        changed = normalizePercent(&parameter.substituteTaxRate, allowsWhole: false) || changed
        changed = normalizePercent(&parameter.profitabilityCoefficient, allowsWhole: true) || changed
        changed = normalizePercent(&parameter.inpsRate, allowsWhole: false) || changed
        changed = normalizePercent(&parameter.prudentialExtraRate, allowsWhole: false) || changed

        if parameter.minimumMarginThreshold < 0 {
            parameter.minimumMarginThreshold = abs(parameter.minimumMarginThreshold).roundedMoney
            changed = true
        }

        return changed
    }

    private static func normalizePercent(_ value: inout Decimal, allowsWhole: Bool) -> Bool {
        guard value > 1 || (!allowsWhole && value == 1) else { return false }

        if value == 1, !allowsWhole {
            value = value / 100
        } else {
            value = value <= 10 ? value / 10 : value / 100
        }
        if value > 1 {
            value = value / 100
        }
        return true
    }
}

enum TaxParameterInputParser {
    static func percent(_ text: String, fallback: Decimal = 0, allowsWhole: Bool = false, allowsZero: Bool = false) -> Decimal {
        guard let value = MoneyFormatting.parseDecimalOrNil(text) else { return fallback }
        if value == 0, allowsZero { return 0 }
        guard value > 0 else { return fallback }
        return normalizedPercent(value, allowsWhole: allowsWhole)
    }

    static func normalizedPercent(_ value: Decimal, allowsWhole: Bool = false) -> Decimal {
        guard value > 0 else { return 0 }
        if allowsWhole, value == 1 {
            return 1
        }
        return value >= 1 ? value / 100 : value
    }
}
