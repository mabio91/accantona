import Foundation

struct ReserveBreakdown {
    let income: Decimal
    let taxableBase: Decimal
    let substituteTax: Decimal
    let inps: Decimal
    let theoreticalReserve: Decimal
    let prudentialReserve: Decimal
    let availableAfterReserve: Decimal
    let appliedRate: Decimal
}

struct CoverageResult {
    let required: Decimal
    let available: Decimal
    let margin: Decimal
    let threshold: Decimal

    var ratio: Decimal {
        guard required > 0 else { return 1 }
        return min(available / required, 1)
    }

    var status: CoverageStatus {
        if margin < 0 { return .deficit }
        if margin < threshold { return .lowMargin }
        return .covered
    }
}

enum CoverageStatus {
    case covered
    case lowMargin
    case deficit
    case unknown

    var title: String {
        switch self {
        case .covered: "Coperto"
        case .lowMargin: "Coperto, margine basso"
        case .deficit: "Da recuperare"
        case .unknown: "Dato non disponibile"
        }
    }

    var symbol: String {
        switch self {
        case .covered: "checkmark.seal.fill"
        case .lowMargin: "exclamationmark.triangle.fill"
        case .deficit: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

enum TaxCalculator {
    static func reserveBreakdown(for income: Decimal, parameters: TaxParameters) -> ReserveBreakdown {
        let taxableBase = income * parameters.profitabilityCoefficient
        let substituteTax = taxableBase * parameters.substituteTaxRate
        let inps = taxableBase * parameters.inpsRate
        let theoretical = substituteTax + inps
        let prudential = theoretical + income * parameters.prudentialExtraRate

        return ReserveBreakdown(
            income: income,
            taxableBase: taxableBase,
            substituteTax: substituteTax,
            inps: inps,
            theoreticalReserve: theoretical,
            prudentialReserve: prudential,
            availableAfterReserve: income - prudential,
            appliedRate: parameters.appliedReserveRate
        )
    }

    static func coverage(required: Decimal, available: Decimal, threshold: Decimal) -> CoverageResult {
        CoverageResult(
            required: required,
            available: available,
            margin: available - required,
            threshold: threshold
        )
    }

    static func requiredIncomeToRecover(deficit: Decimal, parameters: TaxParameters) -> Decimal {
        guard deficit > 0, parameters.appliedReserveRate > 0 else { return 0 }
        return deficit / parameters.appliedReserveRate
    }
}

