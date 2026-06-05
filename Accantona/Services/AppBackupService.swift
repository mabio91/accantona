import Foundation
import SwiftData

struct AppBackupSummary: Equatable {
    let setups: Int
    let invoices: Int
    let taxParameters: Int
    let reserves: Int
    let snapshots: Int
    let movements: Int
    let taxPayments: Int
    let deadlines: Int
    let taxReturns: Int

    var totalRecords: Int {
        setups
            + invoices
            + taxParameters
            + reserves
            + snapshots
            + movements
            + taxPayments
            + deadlines
            + taxReturns
    }
}

struct AppBackup: Codable {
    static let currentSchemaVersion = 1

    let appName: String
    let schemaVersion: Int
    let createdAt: Date
    let setups: [AppSetupBackupRecord]
    let invoices: [InvoiceBackupRecord]
    let taxParameters: [TaxParametersBackupRecord]
    let reserves: [ReserveEntryBackupRecord]
    let snapshots: [TaxAccountSnapshotBackupRecord]
    let movements: [TaxAccountMovementBackupRecord]
    let taxPayments: [TaxPaymentBackupRecord]
    let deadlines: [TaxDeadlineBackupRecord]
    let taxReturns: [TaxReturnSummaryBackupRecord]

    var summary: AppBackupSummary {
        AppBackupSummary(
            setups: setups.count,
            invoices: invoices.count,
            taxParameters: taxParameters.count,
            reserves: reserves.count,
            snapshots: snapshots.count,
            movements: movements.count,
            taxPayments: taxPayments.count,
            deadlines: deadlines.count,
            taxReturns: taxReturns.count
        )
    }
}

enum AppBackupError: LocalizedError {
    case missingFileContents
    case unsupportedVersion(Int)
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case .missingFileContents:
            "Il file selezionato non contiene dati leggibili."
        case .unsupportedVersion(let version):
            "Questo backup usa una versione non supportata (\(version))."
        case .emptyBackup:
            "Il backup non contiene record da ripristinare."
        }
    }
}

@MainActor
enum AppBackupService {
    static func defaultFilename(now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "Accantona-backup-\(formatter.string(from: now))"
    }

    static func encodedBackup(context: ModelContext, now: Date = .now) throws -> Data {
        let backup = try makeBackup(context: context, now: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(backup)
    }

    static func preview(from data: Data) throws -> AppBackupSummary {
        try decodedBackup(from: data).summary
    }

    @discardableResult
    static func restoreBackup(from data: Data, into context: ModelContext) throws -> AppBackupSummary {
        let backup = try decodedBackup(from: data)
        guard backup.summary.totalRecords > 0 else {
            throw AppBackupError.emptyBackup
        }

        do {
            try deleteAllModels(in: context)
            insert(backup, into: context)
            try context.save()
            return backup.summary
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    static func deleteAllData(in context: ModelContext) throws -> AppBackupSummary {
        do {
            let summary = try currentSummary(context: context)
            try deleteAllModels(in: context)
            try context.save()
            return summary
        } catch {
            context.rollback()
            throw error
        }
    }

    static func currentSummary(context: ModelContext) throws -> AppBackupSummary {
        AppBackupSummary(
            setups: try count(AppSetup.self, context: context),
            invoices: try count(Invoice.self, context: context),
            taxParameters: try count(TaxParameters.self, context: context),
            reserves: try count(ReserveEntry.self, context: context),
            snapshots: try count(TaxAccountSnapshot.self, context: context),
            movements: try count(TaxAccountMovement.self, context: context),
            taxPayments: try count(TaxPayment.self, context: context),
            deadlines: try count(TaxDeadline.self, context: context),
            taxReturns: try count(TaxReturnSummary.self, context: context)
        )
    }

    private static func makeBackup(context: ModelContext, now: Date) throws -> AppBackup {
        AppBackup(
            appName: "Accantona",
            schemaVersion: AppBackup.currentSchemaVersion,
            createdAt: now,
            setups: try fetch(AppSetup.self, context: context).map(AppSetupBackupRecord.init),
            invoices: try fetch(Invoice.self, context: context).map(InvoiceBackupRecord.init),
            taxParameters: try fetch(TaxParameters.self, context: context).map(TaxParametersBackupRecord.init),
            reserves: try fetch(ReserveEntry.self, context: context).map(ReserveEntryBackupRecord.init),
            snapshots: try fetch(TaxAccountSnapshot.self, context: context).map(TaxAccountSnapshotBackupRecord.init),
            movements: try fetch(TaxAccountMovement.self, context: context).map(TaxAccountMovementBackupRecord.init),
            taxPayments: try fetch(TaxPayment.self, context: context).map(TaxPaymentBackupRecord.init),
            deadlines: try fetch(TaxDeadline.self, context: context).map(TaxDeadlineBackupRecord.init),
            taxReturns: try fetch(TaxReturnSummary.self, context: context).map(TaxReturnSummaryBackupRecord.init)
        )
    }

    private static func decodedBackup(from data: Data) throws -> AppBackup {
        guard !data.isEmpty else {
            throw AppBackupError.missingFileContents
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackup.self, from: data)
        guard backup.schemaVersion == AppBackup.currentSchemaVersion else {
            throw AppBackupError.unsupportedVersion(backup.schemaVersion)
        }
        return backup
    }

    private static func insert(_ backup: AppBackup, into context: ModelContext) {
        backup.setups.map { $0.model() }.forEach(context.insert)
        backup.taxParameters.map { $0.model() }.forEach(context.insert)
        backup.invoices.map { $0.model() }.forEach(context.insert)
        backup.reserves.map { $0.model() }.forEach(context.insert)
        backup.snapshots.map { $0.model() }.forEach(context.insert)
        backup.movements.map { $0.model() }.forEach(context.insert)
        backup.taxPayments.map { $0.model() }.forEach(context.insert)
        backup.deadlines.map { $0.model() }.forEach(context.insert)
        backup.taxReturns.map { $0.model() }.forEach(context.insert)
    }

    private static func deleteAllModels(in context: ModelContext) throws {
        try delete(AppSetup.self, context: context)
        try delete(Invoice.self, context: context)
        try delete(TaxParameters.self, context: context)
        try delete(ReserveEntry.self, context: context)
        try delete(TaxAccountSnapshot.self, context: context)
        try delete(TaxAccountMovement.self, context: context)
        try delete(TaxPayment.self, context: context)
        try delete(TaxDeadline.self, context: context)
        try delete(TaxReturnSummary.self, context: context)
    }

    private static func fetch<T: PersistentModel>(_ model: T.Type, context: ModelContext) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    private static func count<T: PersistentModel>(_ model: T.Type, context: ModelContext) throws -> Int {
        try fetch(model, context: context).count
    }

    private static func delete<T: PersistentModel>(_ model: T.Type, context: ModelContext) throws {
        for record in try fetch(model, context: context) {
            context.delete(record)
        }
    }
}

struct AppSetupBackupRecord: Codable {
    let id: UUID
    let onboardingCompleted: Bool
    let completedAt: Date?
    let updatedAt: Date
    let regimeName: String

    init(_ setup: AppSetup) {
        id = setup.id
        onboardingCompleted = setup.onboardingCompleted
        completedAt = setup.completedAt
        updatedAt = setup.updatedAt
        regimeName = setup.regimeName
    }

    func model() -> AppSetup {
        AppSetup(
            id: id,
            onboardingCompleted: onboardingCompleted,
            completedAt: completedAt,
            updatedAt: updatedAt,
            regimeName: regimeName
        )
    }
}

struct InvoiceBackupRecord: Codable {
    let id: UUID
    let number: String
    let client: String
    let project: String
    let invoiceDescription: String
    let issueDate: Date
    let expectedPaymentDate: Date?
    let paidDate: Date?
    let amount: Decimal
    let stampDuty: Decimal
    let statusRaw: String
    let managementYear: Int
    let fiscalYear: Int?
    let notes: String

    init(_ invoice: Invoice) {
        id = invoice.id
        number = invoice.number
        client = invoice.client
        project = invoice.project
        invoiceDescription = invoice.invoiceDescription
        issueDate = invoice.issueDate
        expectedPaymentDate = invoice.expectedPaymentDate
        paidDate = invoice.paidDate
        amount = invoice.amount
        stampDuty = invoice.stampDuty
        statusRaw = invoice.statusRaw
        managementYear = invoice.managementYear
        fiscalYear = invoice.fiscalYear
        notes = invoice.notes
    }

    func model() -> Invoice {
        let invoice = Invoice(
            id: id,
            number: number,
            client: client,
            project: project,
            description: invoiceDescription,
            issueDate: issueDate,
            expectedPaymentDate: expectedPaymentDate,
            paidDate: paidDate,
            amount: amount,
            stampDuty: stampDuty,
            status: InvoiceStatus(rawValue: statusRaw) ?? .issued,
            managementYear: managementYear,
            fiscalYear: fiscalYear,
            notes: notes
        )
        invoice.statusRaw = statusRaw
        return invoice
    }
}

struct TaxParametersBackupRecord: Codable {
    let id: UUID
    let year: Int
    let substituteTaxRate: Decimal
    let profitabilityCoefficient: Decimal
    let inpsRate: Decimal
    let prudentialExtraRate: Decimal
    let minimumMarginThreshold: Decimal

    init(_ parameters: TaxParameters) {
        id = parameters.id
        year = parameters.year
        substituteTaxRate = parameters.substituteTaxRate
        profitabilityCoefficient = parameters.profitabilityCoefficient
        inpsRate = parameters.inpsRate
        prudentialExtraRate = parameters.prudentialExtraRate
        minimumMarginThreshold = parameters.minimumMarginThreshold
    }

    func model() -> TaxParameters {
        TaxParameters(
            id: id,
            year: year,
            substituteTaxRate: substituteTaxRate,
            profitabilityCoefficient: profitabilityCoefficient,
            inpsRate: inpsRate,
            prudentialExtraRate: prudentialExtraRate,
            minimumMarginThreshold: minimumMarginThreshold
        )
    }
}

struct ReserveEntryBackupRecord: Codable {
    let id: UUID
    let invoiceId: UUID?
    let date: Date
    let incomeAmount: Decimal
    let appliedRate: Decimal
    let theoreticalAmount: Decimal
    let prudentialAmount: Decimal
    let actualReservedAmount: Decimal
    let transferDate: Date?
    let statusRaw: String
    let notes: String

    init(_ reserve: ReserveEntry) {
        id = reserve.id
        invoiceId = reserve.invoiceId
        date = reserve.date
        incomeAmount = reserve.incomeAmount
        appliedRate = reserve.appliedRate
        theoreticalAmount = reserve.theoreticalAmount
        prudentialAmount = reserve.prudentialAmount
        actualReservedAmount = reserve.actualReservedAmount
        transferDate = reserve.transferDate
        statusRaw = reserve.statusRaw
        notes = reserve.notes
    }

    func model() -> ReserveEntry {
        let reserve = ReserveEntry(
            id: id,
            invoiceId: invoiceId,
            date: date,
            incomeAmount: incomeAmount,
            appliedRate: appliedRate,
            theoreticalAmount: theoreticalAmount,
            prudentialAmount: prudentialAmount,
            actualReservedAmount: actualReservedAmount,
            transferDate: transferDate,
            status: ReserveStatus(rawValue: statusRaw) ?? .pending,
            notes: notes
        )
        reserve.statusRaw = statusRaw
        return reserve
    }
}

struct TaxAccountSnapshotBackupRecord: Codable {
    let id: UUID
    let balance: Decimal
    let updatedAt: Date

    init(_ snapshot: TaxAccountSnapshot) {
        id = snapshot.id
        balance = snapshot.balance
        updatedAt = snapshot.updatedAt
    }

    func model() -> TaxAccountSnapshot {
        TaxAccountSnapshot(id: id, balance: balance, updatedAt: updatedAt)
    }
}

struct TaxAccountMovementBackupRecord: Codable {
    let id: UUID
    let date: Date
    let createdAt: Date?
    let amount: Decimal
    let kind: String
    let note: String
    let sourceId: UUID?

    init(_ movement: TaxAccountMovement) {
        id = movement.id
        date = movement.date
        createdAt = movement.createdAt
        amount = movement.amount
        kind = movement.kind
        note = movement.note
        sourceId = movement.sourceId
    }

    func model() -> TaxAccountMovement {
        let movement = TaxAccountMovement(
            id: id,
            date: date,
            createdAt: createdAt ?? date,
            amount: amount,
            kind: kind,
            note: note,
            sourceId: sourceId
        )
        movement.createdAt = createdAt
        return movement
    }
}

struct TaxPaymentBackupRecord: Codable {
    let id: UUID
    let paymentDate: Date
    let taxYear: Int
    let deadlineId: UUID?
    let typeRaw: String
    let sectionRaw: String
    let code: String
    let amountDebt: Decimal?
    let amountPaid: Decimal
    let amountCompensated: Decimal
    let notes: String

    init(_ payment: TaxPayment) {
        id = payment.id
        paymentDate = payment.paymentDate
        taxYear = payment.taxYear
        deadlineId = payment.deadlineId
        typeRaw = payment.typeRaw
        sectionRaw = payment.sectionRaw
        code = payment.code
        amountDebt = payment.amountDebt
        amountPaid = payment.amountPaid
        amountCompensated = payment.amountCompensated
        notes = payment.notes
    }

    func model() -> TaxPayment {
        let payment = TaxPayment(
            id: id,
            paymentDate: paymentDate,
            taxYear: taxYear,
            deadlineId: deadlineId,
            type: TaxPaymentType(rawValue: typeRaw) ?? .other,
            section: TaxPaymentSection(rawValue: sectionRaw) ?? .other,
            code: code,
            amountDebt: amountDebt,
            amountPaid: amountPaid,
            amountCompensated: amountCompensated,
            notes: notes
        )
        payment.typeRaw = typeRaw
        payment.sectionRaw = sectionRaw
        payment.amountDebt = amountDebt
        return payment
    }
}

struct TaxDeadlineBackupRecord: Codable {
    let id: UUID
    let title: String
    let date: Date
    let taxYear: Int
    let estimatedAmount: Decimal
    let certaintyRaw: String
    let notes: String

    init(_ deadline: TaxDeadline) {
        id = deadline.id
        title = deadline.title
        date = deadline.date
        taxYear = deadline.taxYear
        estimatedAmount = deadline.estimatedAmount
        certaintyRaw = deadline.certaintyRaw
        notes = deadline.notes
    }

    func model() -> TaxDeadline {
        let deadline = TaxDeadline(
            id: id,
            title: title,
            date: date,
            taxYear: taxYear,
            estimatedAmount: estimatedAmount,
            certainty: DeadlineCertainty(rawValue: certaintyRaw) ?? .estimate,
            notes: notes
        )
        deadline.certaintyRaw = certaintyRaw
        return deadline
    }
}

struct TaxReturnSummaryBackupRecord: Codable {
    let id: UUID
    let declarationYear: Int
    let taxPeriod: Int
    let revenues: Decimal
    let profitabilityCoefficient: Decimal
    let grossIncome: Decimal
    let deductedContributions: Decimal
    let taxableNetIncome: Decimal
    let substituteTaxDue: Decimal
    let substituteTaxAdvancesPaid: Decimal
    let substituteTaxBalanceOrCredit: Decimal
    let inpsDue: Decimal
    let inpsAdvancesPaid: Decimal
    let inpsBalanceOrCredit: Decimal
    let notes: String

    init(_ summary: TaxReturnSummary) {
        id = summary.id
        declarationYear = summary.declarationYear
        taxPeriod = summary.taxPeriod
        revenues = summary.revenues
        profitabilityCoefficient = summary.profitabilityCoefficient
        grossIncome = summary.grossIncome
        deductedContributions = summary.deductedContributions
        taxableNetIncome = summary.taxableNetIncome
        substituteTaxDue = summary.substituteTaxDue
        substituteTaxAdvancesPaid = summary.substituteTaxAdvancesPaid
        substituteTaxBalanceOrCredit = summary.substituteTaxBalanceOrCredit
        inpsDue = summary.inpsDue
        inpsAdvancesPaid = summary.inpsAdvancesPaid
        inpsBalanceOrCredit = summary.inpsBalanceOrCredit
        notes = summary.notes
    }

    func model() -> TaxReturnSummary {
        TaxReturnSummary(
            id: id,
            declarationYear: declarationYear,
            taxPeriod: taxPeriod,
            revenues: revenues,
            profitabilityCoefficient: profitabilityCoefficient,
            grossIncome: grossIncome,
            deductedContributions: deductedContributions,
            taxableNetIncome: taxableNetIncome,
            substituteTaxDue: substituteTaxDue,
            substituteTaxAdvancesPaid: substituteTaxAdvancesPaid,
            substituteTaxBalanceOrCredit: substituteTaxBalanceOrCredit,
            inpsDue: inpsDue,
            inpsAdvancesPaid: inpsAdvancesPaid,
            inpsBalanceOrCredit: inpsBalanceOrCredit,
            notes: notes
        )
    }
}
