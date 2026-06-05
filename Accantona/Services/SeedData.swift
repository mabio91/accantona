import Foundation
import SwiftData

enum SeedData {
    static func installIfNeeded(context: ModelContext) {
        if AppLaunchMode.demoScenario {
            installDemoScenario(context: context)
            return
        }

        let setupDescriptor = FetchDescriptor<AppSetup>()
        let setups = fetch(setupDescriptor, context: context)
        let parameters = fetch(FetchDescriptor<TaxParameters>(), context: context)
        let didNormalizeParameters = parameters.reduce(false) { partial, parameter in
            TaxParameterSanitizer.normalize(parameter) || partial
        }

        guard setups.isEmpty else {
            if didNormalizeParameters {
                save(context)
            }
            return
        }

        let hasParameters = !parameters.isEmpty
        let hasDeadlines = !(fetch(FetchDescriptor<TaxDeadline>(), context: context).isEmpty)
        let hasMovements = !(fetch(FetchDescriptor<TaxAccountMovement>(), context: context).isEmpty)
        let hasSnapshots = !(fetch(FetchDescriptor<TaxAccountSnapshot>(), context: context).isEmpty)
        let hasInvoices = !(fetch(FetchDescriptor<Invoice>(), context: context).isEmpty)
        let hasExistingData = hasParameters || hasDeadlines || hasMovements || hasSnapshots || hasInvoices

        context.insert(AppSetup(
            onboardingCompleted: hasExistingData,
            completedAt: hasExistingData ? .now : nil
        ))

        save(context)
    }

    static func installDemoScenario(context: ModelContext) {
        guard fetch(FetchDescriptor<AppSetup>(), context: context).isEmpty else { return }

        let setup = AppSetup(onboardingCompleted: true, completedAt: date("2026-05-05"))
        let parameters = TaxParameters(
            year: 2026,
            substituteTaxRate: decimal("0.15"),
            profitabilityCoefficient: decimal("0.78"),
            inpsRate: decimal("0.2607"),
            prudentialExtraRate: decimal("0.01"),
            minimumMarginThreshold: decimal("250")
        )
        let june = TaxDeadline(
            title: "Saldo + primo acconto giugno",
            date: date("2026-06-30"),
            taxYear: 2025,
            estimatedAmount: decimal("7399.27"),
            certainty: .estimate,
            notes: "Demo e2e Accantona"
        )
        let november = TaxDeadline(
            title: "Secondo acconto novembre",
            date: date("2026-11-30"),
            taxYear: 2026,
            estimatedAmount: decimal("4536.76"),
            certainty: .estimate,
            notes: "Demo e2e Accantona"
        )
        let invoicePaidDate = date("2026-02-16")
        let invoice = Invoice(
            number: "E2E-001",
            client: "Studio Demo",
            project: "Consulenza SwiftUI",
            description: "Incasso storico per verifica accantonamento",
            issueDate: date("2026-02-01"),
            paidDate: invoicePaidDate,
            amount: decimal("3333.34"),
            status: .paid,
            managementYear: 2026,
            fiscalYear: 2026,
            notes: "Demo e2e Accantona"
        )
        let breakdown = TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: parameters)
        let reserve = ReserveEntry(
            invoiceId: invoice.id,
            date: invoicePaidDate,
            incomeAmount: invoice.amount,
            appliedRate: breakdown.appliedRate,
            theoreticalAmount: breakdown.theoreticalReserve.roundedMoney,
            prudentialAmount: breakdown.prudentialReserve.roundedMoney,
            actualReservedAmount: decimal("500"),
            transferDate: date("2026-02-17"),
            status: .partial,
            notes: "Demo e2e Accantona"
        )
        let initialBalance = OnboardingAccounting.makeInitialBalanceMovement(
            amount: decimal("7534.41"),
            setup: setup
        )
        initialBalance.date = date("2026-01-01")
        initialBalance.createdAt = date("2026-01-01")
        let reserveMovement = TaxAccountMovement(
            date: date("2026-02-17"),
            createdAt: date("2026-02-17"),
            amount: decimal("500"),
            kind: "Accantonamento",
            note: "Accantonamento parziale demo E2E-001",
            sourceId: reserve.id
        )
        let taxPayment = TaxPayment(
            paymentDate: date("2026-06-16"),
            taxYear: 2025,
            deadlineId: june.id,
            type: .balance,
            section: .erario,
            code: "1790",
            amountDebt: decimal("7399.27"),
            amountPaid: decimal("7399.27"),
            notes: "F24 demo collegato a giugno"
        )
        let taxPaymentMovement = TaxPaymentAccounting.makeLedgerMovement(for: taxPayment)
        let taxReturn = TaxReturnSummary(
            declarationYear: 2024,
            taxPeriod: 2023,
            revenues: decimal("41646"),
            profitabilityCoefficient: decimal("0.78"),
            grossIncome: decimal("32484"),
            deductedContributions: decimal("11598"),
            taxableNetIncome: decimal("20886"),
            substituteTaxDue: decimal("1044"),
            substituteTaxAdvancesPaid: decimal("1882"),
            substituteTaxBalanceOrCredit: decimal("-838"),
            notes: "Dati reali demo 2023"
        )

        context.insert(setup)
        context.insert(parameters)
        context.insert(june)
        context.insert(november)
        context.insert(invoice)
        context.insert(reserve)
        context.insert(initialBalance)
        context.insert(reserveMovement)
        context.insert(taxPayment)
        context.insert(taxPaymentMovement)
        context.insert(taxReturn)

        save(context)
    }

    private static func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, context: ModelContext) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            assertionFailure("SwiftData fetch failed during seed: \(error)")
            return []
        }
    }

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("SwiftData seed save failed: \(error)")
        }
    }

    private static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) ?? .now
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}
