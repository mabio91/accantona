import Foundation
import SwiftUI

enum SimulatorTarget: String, CaseIterable, Identifiable {
    case june = "Giugno"
    case november = "Novembre"
    case fullYear = "Anno completo"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .june: "sun.max.fill"
        case .november: "cloud.sun.fill"
        case .fullYear: "calendar.circle.fill"
        }
    }

    func includes(_ deadline: TaxDeadline) -> Bool {
        switch self {
        case .june:
            let title = deadline.title.lowercased()
            let month = Calendar.current.component(.month, from: deadline.date)
            return month == 6 || title.contains("giugno") || title.contains("saldo") || title.contains("primo")
        case .november:
            let title = deadline.title.lowercased()
            let month = Calendar.current.component(.month, from: deadline.date)
            return month == 11 || title.contains("novembre") || title.contains("secondo")
        case .fullYear:
            return true
        }
    }
}

struct SimulationInput {
    let newIncome: Decimal
    let expectedIncomeDate: Date
    let reserveRate: Decimal
    let includeExpectedInvoices: Bool
    let includeRecoveries: Bool
    let target: SimulatorTarget
}

struct SimulationResult {
    let targetTitle: String
    let targetDate: Date
    let projection: DeadlineCoverageProjection
    let newReserveAmount: Decimal
    let availableAfterReserve: Decimal
    let requiredIncomeToCoverDeficit: Decimal
    let skippableAmount: Decimal
    let resultMessage: String

    var isCovered: Bool { projection.margin >= 0 }

    var statusTitle: String {
        isCovered ? "Sei coperto" : "Vai sotto"
    }

    var statusColor: Color {
        isCovered ? AppColor.sage : AppColor.coral
    }
}

enum SimulatorCalculator {
    static func result(
        input: SimulationInput,
        deadlines: [TaxDeadline],
        parameters: TaxParameters?,
        invoices: [Invoice],
        reserves: [ReserveEntry],
        taxPayments: [TaxPayment],
        snapshots: [TaxAccountSnapshot],
        movements: [TaxAccountMovement]
    ) -> SimulationResult? {
        let sortedDeadlines = deadlines.sorted { $0.date < $1.date }
        guard let targetDeadline = targetDeadline(for: input.target, in: sortedDeadlines) else { return nil }
        let selectedDeadlines = sortedDeadlines.filter { deadline in
            input.target == .fullYear || deadline.date <= targetDeadline.date
        }

        let scenarioParameters = parametersForSimulation(rate: input.reserveRate, base: parameters)
        let scenarioInvoices = invoicesForSimulation(input: input, invoices: invoices)
        let scenarioReserves = input.includeRecoveries ? reserves : []

        var startingBalance: Decimal?
        var previousDeadlineDate: Date?
        var finalProjection: DeadlineCoverageProjection?

        for deadline in selectedDeadlines {
            let projection = DeadlineCoverageCalculator.projection(
                for: deadline,
                parameters: scenarioParameters,
                invoices: scenarioInvoices,
                reserves: scenarioReserves,
                taxPayments: taxPayments,
                snapshots: snapshots,
                movements: movements,
                parameterCatalog: scenarioParameters.map { [$0] } ?? [],
                startingBalance: startingBalance,
                fromDateExclusive: previousDeadlineDate
            )
            startingBalance = projection.projectedBalance - projection.remainingDue
            previousDeadlineDate = deadline.date
            finalProjection = projection
        }

        guard let projection = finalProjection else { return nil }

        let newReserve = (input.newIncome * input.reserveRate).roundedMoney
        let availableAfterReserve = (input.newIncome - newReserve).roundedMoney
        let deficit = max(-projection.margin, 0)
        let requiredIncome = input.reserveRate > 0 ? (deficit / input.reserveRate).roundedMoney : 0
        let skippable = max(projection.margin, 0).roundedMoney
        let message = message(for: input, projection: projection, newReserve: newReserve)

        return SimulationResult(
            targetTitle: input.target.rawValue,
            targetDate: projection.deadline.date,
            projection: projection,
            newReserveAmount: newReserve,
            availableAfterReserve: availableAfterReserve,
            requiredIncomeToCoverDeficit: requiredIncome,
            skippableAmount: skippable,
            resultMessage: message
        )
    }

    private static func targetDeadline(for target: SimulatorTarget, in deadlines: [TaxDeadline]) -> TaxDeadline? {
        switch target {
        case .june, .november:
            return deadlines.first { target.includes($0) }
        case .fullYear:
            return deadlines.last
        }
    }

    private static func parametersForSimulation(rate: Decimal, base: TaxParameters?) -> TaxParameters? {
        guard let base else { return nil }
        return TaxParameters(
            year: base.year,
            substituteTaxRate: rate,
            profitabilityCoefficient: 1,
            inpsRate: 0,
            prudentialExtraRate: 0,
            minimumMarginThreshold: base.minimumMarginThreshold
        )
    }

    private static func invoicesForSimulation(input: SimulationInput, invoices: [Invoice]) -> [Invoice] {
        var scenarioInvoices = input.includeExpectedInvoices ? invoices : []
        guard input.newIncome > 0 else { return scenarioInvoices }

        scenarioInvoices.append(Invoice(
            number: "SIM",
            client: "Scenario",
            project: "Simulatore",
            description: "Nuovo incasso atteso",
            issueDate: .now,
            expectedPaymentDate: input.expectedIncomeDate,
            amount: input.newIncome,
            status: .issued
        ))

        return scenarioInvoices
    }

    private static func message(for input: SimulationInput, projection: DeadlineCoverageProjection, newReserve: Decimal) -> String {
        let income = MoneyFormatting.money(input.newIncome.roundedMoney)
        let date = input.expectedIncomeDate.formatted(date: .abbreviated, time: .omitted)
        let reserve = MoneyFormatting.money(newReserve)
        let outcome = projection.margin >= 0
            ? "la scadenza resta coperta con \(MoneyFormatting.money(projection.margin.roundedMoney)) di avanzo"
            : "restano da coprire \(MoneyFormatting.money(abs(projection.margin).roundedMoney))"

        return "Se incassi \(income) entro \(date) e accantoni \(reserve), \(outcome)."
    }
}
