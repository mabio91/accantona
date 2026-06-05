import Foundation
import SwiftData

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "Bozza"
    case issued = "Emessa"
    case paid = "Incassata"
    case cancelled = "Annullata"

    var id: String { rawValue }
}

enum ReserveStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Da accantonare"
    case partial = "Parziale"
    case completed = "Accantonata"
    case skipped = "Saltata"
    case recovered = "Recuperata"

    var id: String { rawValue }
}

enum TaxPaymentType: String, Codable, CaseIterable, Identifiable {
    case balance = "Saldo"
    case firstAdvance = "Primo acconto"
    case secondAdvance = "Secondo acconto"
    case stampDuty = "Bollo"
    case other = "Altro"

    var id: String { rawValue }
}

enum TaxPaymentSection: String, Codable, CaseIterable, Identifiable {
    case erario = "Erario"
    case inps = "INPS"
    case other = "Altri enti"

    var id: String { rawValue }
}

enum DeadlineCertainty: String, Codable, CaseIterable {
    case estimate = "Stimato"
    case confirmed = "Certo"
}

@Model
final class AppSetup {
    var id: UUID
    var onboardingCompleted: Bool
    var completedAt: Date?
    var updatedAt: Date
    var regimeName: String

    init(
        id: UUID = UUID(),
        onboardingCompleted: Bool = false,
        completedAt: Date? = nil,
        updatedAt: Date = .now,
        regimeName: String = "Regime forfettario"
    ) {
        self.id = id
        self.onboardingCompleted = onboardingCompleted
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.regimeName = regimeName
    }
}

@Model
final class Invoice {
    var id: UUID
    var number: String
    var client: String
    var project: String
    var invoiceDescription: String
    var issueDate: Date
    var expectedPaymentDate: Date?
    var paidDate: Date?
    var amount: Decimal
    var stampDuty: Decimal
    var statusRaw: String
    var managementYear: Int
    var fiscalYear: Int?
    var notes: String

    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        number: String,
        client: String,
        project: String = "",
        description: String = "",
        issueDate: Date = .now,
        expectedPaymentDate: Date? = nil,
        paidDate: Date? = nil,
        amount: Decimal,
        stampDuty: Decimal = 0,
        status: InvoiceStatus = .issued,
        managementYear: Int = Calendar.current.component(.year, from: .now),
        fiscalYear: Int? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.number = number
        self.client = client
        self.project = project
        self.invoiceDescription = description
        self.issueDate = issueDate
        self.expectedPaymentDate = expectedPaymentDate
        self.paidDate = paidDate
        self.amount = amount
        self.stampDuty = stampDuty
        self.statusRaw = status.rawValue
        self.managementYear = managementYear
        self.fiscalYear = fiscalYear
        self.notes = notes
    }
}

@Model
final class TaxParameters {
    var id: UUID
    var year: Int
    var substituteTaxRate: Decimal
    var profitabilityCoefficient: Decimal
    var inpsRate: Decimal
    var prudentialExtraRate: Decimal
    var minimumMarginThreshold: Decimal

    var appliedReserveRate: Decimal {
        profitabilityCoefficient * (substituteTaxRate + inpsRate) + prudentialExtraRate
    }

    init(
        id: UUID = UUID(),
        year: Int,
        substituteTaxRate: Decimal = 0.15,
        profitabilityCoefficient: Decimal = 0.78,
        inpsRate: Decimal = 0.2607,
        prudentialExtraRate: Decimal = 0.01,
        minimumMarginThreshold: Decimal = 250
    ) {
        self.id = id
        self.year = year
        self.substituteTaxRate = substituteTaxRate
        self.profitabilityCoefficient = profitabilityCoefficient
        self.inpsRate = inpsRate
        self.prudentialExtraRate = prudentialExtraRate
        self.minimumMarginThreshold = minimumMarginThreshold
    }
}

@Model
final class ReserveEntry {
    var id: UUID
    var invoiceId: UUID?
    var date: Date
    var incomeAmount: Decimal
    var appliedRate: Decimal
    var theoreticalAmount: Decimal
    var prudentialAmount: Decimal
    var actualReservedAmount: Decimal
    var transferDate: Date?
    var statusRaw: String
    var notes: String

    var status: ReserveStatus {
        get { ReserveStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        invoiceId: UUID? = nil,
        date: Date = .now,
        incomeAmount: Decimal,
        appliedRate: Decimal,
        theoreticalAmount: Decimal,
        prudentialAmount: Decimal,
        actualReservedAmount: Decimal = 0,
        transferDate: Date? = nil,
        status: ReserveStatus = .pending,
        notes: String = ""
    ) {
        self.id = id
        self.invoiceId = invoiceId
        self.date = date
        self.incomeAmount = incomeAmount
        self.appliedRate = appliedRate
        self.theoreticalAmount = theoreticalAmount
        self.prudentialAmount = prudentialAmount
        self.actualReservedAmount = actualReservedAmount
        self.transferDate = transferDate
        self.statusRaw = status.rawValue
        self.notes = notes
    }
}

@Model
final class TaxAccountSnapshot {
    var id: UUID
    var balance: Decimal
    var updatedAt: Date

    init(id: UUID = UUID(), balance: Decimal = 0, updatedAt: Date = .now) {
        self.id = id
        self.balance = balance
        self.updatedAt = updatedAt
    }
}

@Model
final class TaxAccountMovement {
    var id: UUID
    var date: Date
    var createdAt: Date?
    var amount: Decimal
    var kind: String
    var note: String
    var sourceId: UUID?

    init(id: UUID = UUID(), date: Date = .now, createdAt: Date = .now, amount: Decimal, kind: String, note: String = "", sourceId: UUID? = nil) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.amount = amount
        self.kind = kind
        self.note = note
        self.sourceId = sourceId
    }
}

@Model
final class TaxPayment {
    var id: UUID
    var paymentDate: Date
    var taxYear: Int
    var deadlineId: UUID?
    var typeRaw: String
    var sectionRaw: String
    var code: String
    var amountDebt: Decimal?
    var amountPaid: Decimal
    var amountCompensated: Decimal
    var notes: String

    var type: TaxPaymentType {
        get { TaxPaymentType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var section: TaxPaymentSection {
        get { TaxPaymentSection(rawValue: sectionRaw) ?? .other }
        set { sectionRaw = newValue.rawValue }
    }

    var coveredAmount: Decimal {
        let explicitDebt = amountDebt?.roundedMoney ?? 0
        if explicitDebt > 0 {
            return explicitDebt
        }
        return max(amountPaid + amountCompensated, 0).roundedMoney
    }

    init(
        id: UUID = UUID(),
        paymentDate: Date = .now,
        taxYear: Int,
        deadlineId: UUID? = nil,
        type: TaxPaymentType,
        section: TaxPaymentSection,
        code: String,
        amountDebt: Decimal? = nil,
        amountPaid: Decimal,
        amountCompensated: Decimal = 0,
        notes: String = ""
    ) {
        self.id = id
        self.paymentDate = paymentDate
        self.taxYear = taxYear
        self.deadlineId = deadlineId
        self.typeRaw = type.rawValue
        self.sectionRaw = section.rawValue
        self.code = code
        self.amountDebt = (amountDebt ?? (amountPaid + amountCompensated)).roundedMoney
        self.amountPaid = amountPaid
        self.amountCompensated = amountCompensated
        self.notes = notes
    }
}

@Model
final class TaxDeadline {
    var id: UUID
    var title: String
    var date: Date
    var taxYear: Int
    var estimatedAmount: Decimal
    var certaintyRaw: String
    var notes: String

    var certainty: DeadlineCertainty {
        get { DeadlineCertainty(rawValue: certaintyRaw) ?? .estimate }
        set { certaintyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        taxYear: Int,
        estimatedAmount: Decimal,
        certainty: DeadlineCertainty = .estimate,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.taxYear = taxYear
        self.estimatedAmount = estimatedAmount
        self.certaintyRaw = certainty.rawValue
        self.notes = notes
    }
}

@Model
final class TaxReturnSummary {
    var id: UUID
    var declarationYear: Int
    var taxPeriod: Int
    var revenues: Decimal
    var profitabilityCoefficient: Decimal
    var grossIncome: Decimal
    var deductedContributions: Decimal
    var taxableNetIncome: Decimal
    var substituteTaxDue: Decimal
    var substituteTaxAdvancesPaid: Decimal
    var substituteTaxBalanceOrCredit: Decimal
    var inpsDue: Decimal
    var inpsAdvancesPaid: Decimal
    var inpsBalanceOrCredit: Decimal
    var notes: String

    init(
        id: UUID = UUID(),
        declarationYear: Int = Calendar.current.component(.year, from: .now),
        taxPeriod: Int = Calendar.current.component(.year, from: .now) - 1,
        revenues: Decimal = 0,
        profitabilityCoefficient: Decimal = 0.78,
        grossIncome: Decimal = 0,
        deductedContributions: Decimal = 0,
        taxableNetIncome: Decimal = 0,
        substituteTaxDue: Decimal = 0,
        substituteTaxAdvancesPaid: Decimal = 0,
        substituteTaxBalanceOrCredit: Decimal = 0,
        inpsDue: Decimal = 0,
        inpsAdvancesPaid: Decimal = 0,
        inpsBalanceOrCredit: Decimal = 0,
        notes: String = ""
    ) {
        self.id = id
        self.declarationYear = declarationYear
        self.taxPeriod = taxPeriod
        self.revenues = revenues
        self.profitabilityCoefficient = profitabilityCoefficient
        self.grossIncome = grossIncome
        self.deductedContributions = deductedContributions
        self.taxableNetIncome = taxableNetIncome
        self.substituteTaxDue = substituteTaxDue
        self.substituteTaxAdvancesPaid = substituteTaxAdvancesPaid
        self.substituteTaxBalanceOrCredit = substituteTaxBalanceOrCredit
        self.inpsDue = inpsDue
        self.inpsAdvancesPaid = inpsAdvancesPaid
        self.inpsBalanceOrCredit = inpsBalanceOrCredit
        self.notes = notes
    }
}
