import XCTest
import SwiftData
@testable import Accantona

@MainActor
final class AccantonaCalculationTests: XCTestCase {
    func testTaxCalculatorUsesConfiguredForfettarioRates() {
        let parameters = TaxParameters(year: 2026)
        let breakdown = TaxCalculator.reserveBreakdown(for: decimal("3333.34"), parameters: parameters)

        XCTAssertMoneyEqual(breakdown.theoreticalReserve, decimal("1067.82"))
        XCTAssertMoneyEqual(breakdown.prudentialReserve, decimal("1101.16"))
        XCTAssertMoneyEqual(breakdown.availableAfterReserve, decimal("2232.18"))
        XCTAssertEqual(breakdown.appliedRate, decimal("0.330346"))
    }

    func testMoneyFormattingDistinguishesInvalidDecimalFromZero() {
        XCTAssertEqual(MoneyFormatting.parseDecimalOrNil("0"), decimal("0"))
        XCTAssertEqual(MoneyFormatting.parseDecimalOrNil("1.234,56 €"), decimal("1234.56"))
        XCTAssertNil(MoneyFormatting.parseDecimalOrNil(""))
        XCTAssertNil(MoneyFormatting.parseDecimalOrNil("12abc"))
        XCTAssertEqual(MoneyFormatting.parseDecimal("12abc"), decimal("0"))
    }

    func testDeadlineCoverageIncludesF24RecoveriesAndFutureInvoices() {
        let parameters = TaxParameters(year: 2026)
        let deadline = TaxDeadline(
            title: "Secondo acconto",
            date: date("2026-11-30"),
            taxYear: 2026,
            estimatedAmount: decimal("4536.76")
        )
        let futureInvoice = Invoice(
            number: "10/2026",
            client: "Future",
            expectedPaymentDate: date("2026-10-15"),
            amount: decimal("13500")
        )
        let partialReserve = ReserveEntry(
            date: date("2026-05-01"),
            incomeAmount: decimal("1000"),
            appliedRate: decimal("0.330346"),
            theoreticalAmount: decimal("320.35"),
            prudentialAmount: decimal("330.35"),
            actualReservedAmount: decimal("100"),
            status: .partial
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: deadline,
            parameters: parameters,
            invoices: [futureInvoice],
            reserves: [partialReserve],
            taxPayments: [TaxPayment(paymentDate: date("2026-11-01"), taxYear: 2026, type: .secondAdvance, section: .erario, code: "1792", amountPaid: decimal("100"))],
            snapshots: [],
            movements: [TaxAccountMovement(amount: decimal("135.14"), kind: "Saldo iniziale")]
        )

        XCTAssertMoneyEqual(projection.paidByF24, decimal("100"))
        XCTAssertMoneyEqual(projection.recoverableReserves, decimal("230.35"))
        XCTAssertMoneyEqual(projection.futureReserves, decimal("4459.67"))
        XCTAssertTrue(projection.margin > 0)
    }

    func testSimulatorUsesTimelineThroughNovember() {
        let parameters = TaxParameters(year: 2026)
        let june = TaxDeadline(title: "Saldo + primo acconto", date: date("2026-06-30"), taxYear: 2025, estimatedAmount: decimal("7399.27"))
        let november = TaxDeadline(title: "Secondo acconto", date: date("2026-11-30"), taxYear: 2026, estimatedAmount: decimal("4536.76"))

        let result = SimulatorCalculator.result(
            input: SimulationInput(
                newIncome: decimal("13500"),
                expectedIncomeDate: date("2026-10-15"),
                reserveRate: decimal("0.330346"),
                includeExpectedInvoices: false,
                includeRecoveries: false,
                target: .november
            ),
            deadlines: [june, november],
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [],
            snapshots: [],
            movements: [TaxAccountMovement(amount: decimal("7534.41"), kind: "Saldo iniziale")]
        )

        XCTAssertNotNil(result)
        XCTAssertMoneyEqual(result?.projection.margin ?? 0, decimal("58.05"))
        XCTAssertMoneyEqual(result?.availableAfterReserve ?? 0, decimal("9040.33"))
    }

    func testInvoiceCSVImporterValidatesDuplicatesAndErrors() {
        let csv = """
        numero;cliente;descrizione;data_emissione;data_incasso_prevista;data_incasso;importo;bollo;stato;note;importo_accantonato
        1/2026;Cliente Alpha;Non incassata;2026-01-10;2026-02-10;;3333,34;2;emessa;ok;
        2/2026;Cliente Beta;Incassata senza accantonamento;2026-02-01;2026-02-20;2026-02-18;1800,00;2;incassata;ok;
        3/2026;Cliente Gamma;Incassata parziale;2026-03-01;2026-03-30;2026-03-28;2500,00;2;incassata;ok;500,00
        4/2026;Cliente Delta;Errore stato;2026-04-01;2026-04-30;;1000,00;2;pagata;errore;
        """
        let existing = Invoice(number: "1/2026", client: "Cliente Alpha", issueDate: date("2026-01-10"), amount: decimal("3333.34"))

        let preview = InvoiceCSVImporter.preview(csv: csv, existingInvoices: [existing])

        XCTAssertEqual(preview.importableRows.count, 2)
        XCTAssertEqual(preview.duplicateRows.count, 1)
        XCTAssertEqual(preview.errorRows.count, 1)
        XCTAssertEqual(preview.importableRows.filter { $0.values?.paidDate != nil }.count, 2)
    }

    func testInvoiceDuplicateKeyNormalizesManualAndImportedDuplicates() {
        let issueDate = date("2026-01-10")
        let sameDayWithTime = Calendar.current.date(byAdding: .hour, value: 15, to: issueDate)!

        let stored = InvoiceDuplicateKey(number: " 12/2026 ", client: "Cliente Alpha", issueDate: issueDate)
        let candidate = InvoiceDuplicateKey(number: "12/2026", client: "cliente alpha ", issueDate: sameDayWithTime)

        XCTAssertEqual(stored, candidate)
    }

    func testInvoiceImportAccountingReusesConfiguredFiscalParameterFallback() {
        let oldParameters = TaxParameters(year: 2024, substituteTaxRate: decimal("0.05"))
        let currentParameters = TaxParameters(year: 2026, substituteTaxRate: decimal("0.15"))

        let resolution = InvoiceImportAccounting.parameter(
            forFiscalYear: 2025,
            parameters: [currentParameters, oldParameters],
            createsDefaultForMissingYear: false
        )

        XCTAssertFalse(resolution.shouldInsert)
        XCTAssertEqual(resolution.parameter.year, 2024)
        XCTAssertEqual(resolution.parameter.substituteTaxRate, decimal("0.05"))
    }

    func testInvoiceImportAccountingCreatesDefaultOnlyWhenRequested() {
        let currentParameters = TaxParameters(year: 2026, substituteTaxRate: decimal("0.15"))

        let fallback = InvoiceImportAccounting.parameter(
            forFiscalYear: 2025,
            parameters: [currentParameters],
            createsDefaultForMissingYear: false
        )
        let created = InvoiceImportAccounting.parameter(
            forFiscalYear: 2025,
            parameters: [currentParameters],
            createsDefaultForMissingYear: true
        )

        XCTAssertFalse(fallback.shouldInsert)
        XCTAssertEqual(fallback.parameter.year, 2026)
        XCTAssertTrue(created.shouldInsert)
        XCTAssertEqual(created.parameter.year, 2025)
    }

    func testPartialReserveTransferPlansAreCappedAndProgressive() throws {
        let reserve = ReserveEntry(
            incomeAmount: decimal("3333.34"),
            appliedRate: decimal("0.330346"),
            theoreticalAmount: decimal("1067.82"),
            prudentialAmount: decimal("1101.16"),
            actualReservedAmount: 0,
            status: .pending
        )

        let first = ReserveAccounting.planTransfer(for: reserve, requestedAmount: decimal("500"))
        XCTAssertMoneyEqual(first?.amount ?? 0, decimal("500"))
        ReserveAccounting.apply(try XCTUnwrap(first), to: reserve)

        let second = ReserveAccounting.planTransfer(for: reserve, requestedAmount: decimal("9999"))
        XCTAssertMoneyEqual(second?.amount ?? 0, decimal("601.16"))
        ReserveAccounting.apply(try XCTUnwrap(second), to: reserve)

        XCTAssertMoneyEqual(reserve.actualReservedAmount, decimal("1101.16"))
        XCTAssertEqual(reserve.status, .completed)
    }

    func testF24PaymentLinksLedgerAndDeadlineCoverage() {
        let parameters = TaxParameters(year: 2026)
        let deadline = TaxDeadline(
            title: "Saldo + primo acconto giugno",
            date: date("2026-06-30"),
            taxYear: 2025,
            estimatedAmount: decimal("7399.27")
        )
        let payment = TaxPayment(
            paymentDate: date("2026-06-20"),
            taxYear: 2025,
            type: .balance,
            section: .erario,
            code: "1790",
            amountDebt: decimal("7399.27"),
            amountPaid: decimal("7000"),
            amountCompensated: decimal("399.27")
        )
        let movement = TaxPaymentAccounting.makeLedgerMovement(for: payment)

        let projection = DeadlineCoverageCalculator.projection(
            for: deadline,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [payment],
            snapshots: [TaxAccountSnapshot(balance: decimal("7534.41"), updatedAt: date("2026-01-01"))],
            movements: [movement]
        )

        XCTAssertEqual(movement.sourceId, payment.id)
        XCTAssertMoneyEqual(movement.amount, decimal("-7000"))
        XCTAssertMoneyEqual(projection.paidByF24, decimal("7399.27"))
        XCTAssertMoneyEqual(projection.remainingDue, decimal("0"))
        XCTAssertEqual(projection.certaintyTitle, "Pagato")
    }

    func testF24ExplicitDeadlineLinkUsesCorrectDeadlineOnly() {
        let parameters = TaxParameters(year: 2026)
        let june = TaxDeadline(title: "Saldo + primo acconto", date: date("2026-06-30"), taxYear: 2025, estimatedAmount: decimal("1000"))
        let november = TaxDeadline(title: "Secondo acconto", date: date("2026-11-30"), taxYear: 2026, estimatedAmount: decimal("1000"))
        let payment = TaxPayment(
            paymentDate: date("2026-06-20"),
            taxYear: 2025,
            deadlineId: november.id,
            type: .balance,
            section: .erario,
            code: "1790",
            amountDebt: decimal("400"),
            amountPaid: decimal("400")
        )

        let juneProjection = DeadlineCoverageCalculator.projection(
            for: june,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [payment],
            snapshots: [],
            movements: []
        )
        let novemberProjection = DeadlineCoverageCalculator.projection(
            for: november,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [payment],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(juneProjection.paidByF24, decimal("0"))
        XCTAssertMoneyEqual(novemberProjection.paidByF24, decimal("400"))
    }

    func testF24SamePaymentYearButDifferentTaxYearDoesNotReduceWrongDeadline() {
        let parameters = TaxParameters(year: 2026)
        let june = TaxDeadline(title: "Saldo + primo acconto", date: date("2026-06-30"), taxYear: 2025, estimatedAmount: decimal("1000"))
        let payment = TaxPayment(
            paymentDate: date("2026-06-20"),
            taxYear: 2024,
            type: .balance,
            section: .erario,
            code: "1790",
            amountDebt: decimal("400"),
            amountPaid: decimal("400")
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: june,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [payment],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(projection.paidByF24, decimal("0"))
        XCTAssertMoneyEqual(projection.remainingDue, decimal("1000"))
    }

    func testFirstAdvanceForCurrentYearCoversCombinedJuneDeadline() {
        let parameters = TaxParameters(year: 2026)
        let june = TaxDeadline(title: "Saldo + primo acconto", date: date("2026-06-30"), taxYear: 2025, estimatedAmount: decimal("1000"))
        let firstAdvance = TaxPayment(
            paymentDate: date("2026-06-20"),
            taxYear: 2026,
            type: .firstAdvance,
            section: .erario,
            code: "1791",
            amountDebt: decimal("350"),
            amountPaid: decimal("350")
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: june,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [firstAdvance],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(projection.paidByF24, decimal("350"))
        XCTAssertMoneyEqual(projection.remainingDue, decimal("650"))
    }

    func testFirstAdvanceDoesNotCoverBalanceOnlyDeadline() {
        let parameters = TaxParameters(year: 2026)
        let balanceOnly = TaxDeadline(title: "Saldo imposta sostitutiva", date: date("2026-06-30"), taxYear: 2025, estimatedAmount: decimal("1000"))
        let firstAdvance = TaxPayment(
            paymentDate: date("2026-06-20"),
            taxYear: 2026,
            type: .firstAdvance,
            section: .erario,
            code: "1791",
            amountDebt: decimal("350"),
            amountPaid: decimal("350")
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: balanceOnly,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [firstAdvance],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(projection.paidByF24, decimal("0"))
        XCTAssertMoneyEqual(projection.remainingDue, decimal("1000"))
    }

    func testExplicitLateF24StillCoversLinkedDeadline() {
        let parameters = TaxParameters(year: 2026)
        let june = TaxDeadline(title: "Saldo + primo acconto", date: date("2026-06-30"), taxYear: 2025, estimatedAmount: decimal("1000"))
        let latePayment = TaxPayment(
            paymentDate: date("2026-07-03"),
            taxYear: 2025,
            deadlineId: june.id,
            type: .balance,
            section: .erario,
            code: "1790",
            amountDebt: decimal("1000"),
            amountPaid: decimal("1000")
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: june,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [latePayment],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(projection.paidByF24, decimal("1000"))
        XCTAssertMoneyEqual(projection.remainingDue, decimal("0"))
        XCTAssertEqual(projection.certaintyTitle, "Pagato")
    }

    func testNovemberStampDutyDeadlineDoesNotMatchSecondAdvance() {
        let parameters = TaxParameters(year: 2026)
        let stampDuty = TaxDeadline(title: "Bollo fatture", date: date("2026-11-30"), taxYear: 2026, estimatedAmount: decimal("50"))
        let secondAdvance = TaxPayment(
            paymentDate: date("2026-11-20"),
            taxYear: 2026,
            type: .secondAdvance,
            section: .erario,
            code: "1792",
            amountDebt: decimal("50"),
            amountPaid: decimal("50")
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: stampDuty,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [secondAdvance],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(projection.paidByF24, decimal("0"))
        XCTAssertMoneyEqual(projection.remainingDue, decimal("50"))
    }

    func testPaidDeadlineWithZeroCashIsStillCovered() {
        let parameters = TaxParameters(year: 2026)
        let deadline = TaxDeadline(title: "Saldo + primo acconto", date: date("2026-06-30"), taxYear: 2025, estimatedAmount: decimal("1000"))
        let payment = TaxPayment(
            paymentDate: date("2026-06-20"),
            taxYear: 2025,
            deadlineId: deadline.id,
            type: .balance,
            section: .erario,
            code: "1790",
            amountDebt: decimal("1000"),
            amountPaid: decimal("1000")
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: deadline,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [payment],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(projection.remainingDue, decimal("0"))
        XCTAssertMoneyEqual(projection.margin, decimal("0"))
        XCTAssertEqual(projection.risk, .covered)
    }

    func testF24CreditDoesNotBecomeNegativeCoverage() {
        let parameters = TaxParameters(year: 2026)
        let november = TaxDeadline(title: "Secondo acconto", date: date("2026-11-30"), taxYear: 2026, estimatedAmount: decimal("1000"))
        let credit = TaxPayment(
            paymentDate: date("2026-11-20"),
            taxYear: 2026,
            type: .secondAdvance,
            section: .erario,
            code: "1792",
            amountDebt: 0,
            amountPaid: decimal("-200")
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: november,
            parameters: parameters,
            invoices: [],
            reserves: [],
            taxPayments: [credit],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(projection.paidByF24, decimal("0"))
        XCTAssertMoneyEqual(projection.remainingDue, decimal("1000"))
    }

    func testRecoverableReservesDoNotLookLikeAlreadyCoveredCash() {
        let parameters = TaxParameters(year: 2026)
        let deadline = TaxDeadline(title: "Secondo acconto", date: date("2026-11-30"), taxYear: 2026, estimatedAmount: decimal("300"))
        let reserve = ReserveEntry(
            date: date("2026-04-01"),
            incomeAmount: decimal("1000"),
            appliedRate: decimal("0.33"),
            theoreticalAmount: decimal("300"),
            prudentialAmount: decimal("330"),
            actualReservedAmount: 0,
            status: .pending
        )

        let projection = DeadlineCoverageCalculator.projection(
            for: deadline,
            parameters: parameters,
            invoices: [],
            reserves: [reserve],
            taxPayments: [],
            snapshots: [],
            movements: []
        )

        XCTAssertMoneyEqual(projection.recoverableReserves, decimal("330"))
        XCTAssertEqual(projection.risk, .dependsOnRecovery)
    }

    func testBackdatedMovementCreatedAfterReconciliationStillAffectsLedger() {
        let snapshot = TaxAccountSnapshot(balance: decimal("1000"), updatedAt: date("2026-01-10"))
        let movement = TaxAccountMovement(
            date: date("2026-01-01"),
            createdAt: date("2026-01-11"),
            amount: decimal("250"),
            kind: "Accantonamento"
        )

        let balance = TaxAccountLedger.balance(snapshots: [snapshot], movements: [movement])

        XCTAssertMoneyEqual(balance, decimal("1250"))
    }

    func testInvoiceAccountingUsesHistoricalPaidDate() {
        let paidDate = InvoiceAccounting.paidDate(for: .paid, selectedPaidDate: date("2024-12-20"))

        XCTAssertEqual(paidDate, date("2024-12-20"))
        XCTAssertEqual(InvoiceAccounting.fiscalYear(for: paidDate), 2024)
        XCTAssertNil(InvoiceAccounting.paidDate(for: .issued, selectedPaidDate: date("2024-12-20")))
    }

    func testTaxPaymentLedgerUpdatesAndDeletesBySourceId() {
        let payment = TaxPayment(
            paymentDate: date("2026-06-20"),
            taxYear: 2025,
            type: .balance,
            section: .erario,
            code: "1790",
            amountDebt: decimal("1000"),
            amountPaid: decimal("800")
        )
        let movement = TaxPaymentAccounting.makeLedgerMovement(for: payment)

        payment.amountPaid = decimal("600")
        payment.amountCompensated = decimal("400")
        TaxPaymentAccounting.updateLedgerMovement(movement, for: payment)

        XCTAssertEqual(movement.sourceId, payment.id)
        XCTAssertMoneyEqual(movement.amount, decimal("-600"))

        let remainingMovements = [movement].filter { $0.sourceId != Optional(payment.id) }
        XCTAssertTrue(remainingMovements.isEmpty)
    }

    func testOnboardingInitialBalanceMovementUsesSetupSourceId() {
        let setup = AppSetup()
        let movement = OnboardingAccounting.makeInitialBalanceMovement(amount: decimal("7534.41"), setup: setup)

        XCTAssertEqual(movement.sourceId, setup.id)
        XCTAssertMoneyEqual(movement.amount, decimal("7534.41"))
    }

    func testTaxReturnComparisonCalculatesAnnualDeltas() {
        let summary = TaxReturnSummary(
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
            inpsDue: decimal("0"),
            inpsAdvancesPaid: decimal("0"),
            inpsBalanceOrCredit: decimal("0")
        )
        let invoice = Invoice(
            number: "1/2023",
            client: "Cliente",
            paidDate: date("2023-06-10"),
            amount: decimal("41646"),
            status: .paid
        )
        let reserve = ReserveEntry(
            date: date("2023-06-10"),
            incomeAmount: decimal("41646"),
            appliedRate: decimal("0.330346"),
            theoreticalAmount: decimal("0"),
            prudentialAmount: decimal("13758.79")
        )
        let taxPayment = TaxPayment(
            paymentDate: date("2024-06-30"),
            taxYear: 2023,
            type: .balance,
            section: .erario,
            code: "1790",
            amountDebt: decimal("1044"),
            amountPaid: decimal("1044")
        )

        let comparison = TaxReturnCalculator.comparison(
            for: summary,
            invoices: [invoice],
            reserves: [reserve],
            payments: [taxPayment]
        )

        XCTAssertMoneyEqual(comparison.registeredIncome, decimal("41646"))
        XCTAssertMoneyEqual(comparison.declaredTaxAndInpsDue, decimal("1044"))
        XCTAssertMoneyEqual(comparison.incomeDelta, decimal("0"))
        XCTAssertMoneyEqual(comparison.reserveVsDeclarationDelta, decimal("12714.79"))
        XCTAssertMoneyEqual(comparison.f24VsDeclarationDelta, decimal("0"))
    }

    func testTaxReturnDerivedIncomeHelpers() {
        let gross = TaxReturnCalculator.derivedGrossIncome(
            revenues: decimal("41646"),
            profitabilityCoefficient: decimal("0.78")
        )
        let taxable = TaxReturnCalculator.derivedTaxableIncome(
            grossIncome: decimal("32484"),
            deductedContributions: decimal("11598")
        )

        XCTAssertMoneyEqual(gross, decimal("32483.88"))
        XCTAssertMoneyEqual(taxable, decimal("20886"))
    }

    func testTaxParameterResolverUsesFiscalYearWhenAvailable() {
        let oldParameters = TaxParameters(year: 2024, substituteTaxRate: decimal("0.05"))
        let currentParameters = TaxParameters(year: 2026, substituteTaxRate: decimal("0.15"))
        let invoice = Invoice(
            number: "1/2024",
            client: "Cliente",
            paidDate: date("2024-12-20"),
            amount: decimal("1000"),
            status: .paid,
            fiscalYear: 2024
        )

        let resolved = TaxParameterResolver.parameter(for: invoice, parameters: [currentParameters, oldParameters])

        XCTAssertEqual(resolved?.year, 2024)
        XCTAssertEqual(resolved?.substituteTaxRate, decimal("0.05"))
    }

    func testTaxParameterSanitizerNormalizesPersistedWholeNumberPercentages() {
        let parameters = TaxParameters(
            year: 2026,
            substituteTaxRate: decimal("1.5"),
            profitabilityCoefficient: decimal("78"),
            inpsRate: decimal("26.07"),
            prudentialExtraRate: decimal("1")
        )

        let changed = TaxParameterSanitizer.normalize(parameters)

        XCTAssertTrue(changed)
        XCTAssertEqual(parameters.substituteTaxRate, decimal("0.15"))
        XCTAssertEqual(parameters.profitabilityCoefficient, decimal("0.78"))
        XCTAssertEqual(parameters.inpsRate, decimal("0.2607"))
        XCTAssertEqual(parameters.prudentialExtraRate, decimal("0.01"))
    }

    func testTaxParameterInputParserTreatsOneAsOnePercentForRates() {
        XCTAssertEqual(TaxParameterInputParser.percent("15"), decimal("0.15"))
        XCTAssertEqual(TaxParameterInputParser.percent("26,07"), decimal("0.2607"))
        XCTAssertEqual(TaxParameterInputParser.percent("1"), decimal("0.01"))
        XCTAssertEqual(TaxParameterInputParser.percent("1", allowsWhole: true), decimal("1"))
        XCTAssertEqual(TaxParameterInputParser.percent("78", allowsWhole: true), decimal("0.78"))
    }

    func testTaxReturnComparisonUsesLinkedInvoiceFiscalYearForReserves() {
        let invoice = Invoice(
            number: "1/2023",
            client: "Cliente",
            paidDate: date("2023-12-31"),
            amount: decimal("1000"),
            status: .paid,
            fiscalYear: 2023
        )
        let reserve = ReserveEntry(
            invoiceId: invoice.id,
            date: date("2024-01-02"),
            incomeAmount: decimal("1000"),
            appliedRate: decimal("0.33"),
            theoreticalAmount: decimal("300"),
            prudentialAmount: decimal("330")
        )
        let summary = TaxReturnSummary(taxPeriod: 2023, revenues: decimal("1000"), substituteTaxDue: decimal("100"))

        let comparison = TaxReturnCalculator.comparison(
            for: summary,
            invoices: [invoice],
            reserves: [reserve],
            payments: []
        )

        XCTAssertMoneyEqual(comparison.calculatedReserves, decimal("330"))
    }

    func testBackupRestoreRoundTripPreservesAllStoresAndLinks() throws {
        let container = try ModelContainer.accantonaContainer(inMemory: true)
        let context = ModelContext(container)
        let setup = AppSetup(onboardingCompleted: true, completedAt: date("2026-01-01"), regimeName: "Regime test")
        let parameters = TaxParameters(year: 2026, substituteTaxRate: decimal("0.15"), minimumMarginThreshold: decimal("300"))
        let invoice = Invoice(
            number: "B-001",
            client: "Cliente Backup",
            project: "Audit",
            description: "Fattura da preservare",
            issueDate: date("2026-02-01"),
            expectedPaymentDate: date("2026-02-20"),
            paidDate: date("2026-02-18"),
            amount: decimal("1200.50"),
            stampDuty: decimal("2"),
            status: .paid,
            managementYear: 2026,
            fiscalYear: 2026,
            notes: "Nota fattura"
        )
        let reserve = ReserveEntry(
            invoiceId: invoice.id,
            date: date("2026-02-18"),
            incomeAmount: invoice.amount,
            appliedRate: decimal("0.330346"),
            theoreticalAmount: decimal("396.58"),
            prudentialAmount: decimal("406.58"),
            actualReservedAmount: decimal("200"),
            transferDate: date("2026-02-19"),
            status: .partial,
            notes: "Nota riserva"
        )
        let snapshot = TaxAccountSnapshot(balance: decimal("700"), updatedAt: date("2026-01-10"))
        let movement = TaxAccountMovement(
            date: date("2026-02-19"),
            createdAt: date("2026-02-19"),
            amount: decimal("200"),
            kind: "Accantonamento",
            note: "Movimento backup",
            sourceId: reserve.id
        )
        let deadline = TaxDeadline(
            title: "Secondo acconto",
            date: date("2026-11-30"),
            taxYear: 2026,
            estimatedAmount: decimal("500"),
            certainty: .confirmed,
            notes: "Nota scadenza"
        )
        let payment = TaxPayment(
            paymentDate: date("2026-11-20"),
            taxYear: 2026,
            deadlineId: deadline.id,
            type: .secondAdvance,
            section: .erario,
            code: "1792",
            amountDebt: decimal("500"),
            amountPaid: decimal("450"),
            amountCompensated: decimal("50"),
            notes: "Nota F24"
        )
        let taxReturn = TaxReturnSummary(
            declarationYear: 2026,
            taxPeriod: 2025,
            revenues: decimal("1000"),
            profitabilityCoefficient: decimal("0.78"),
            substituteTaxDue: decimal("100"),
            notes: "Nota dichiarazione"
        )

        context.insert(setup)
        context.insert(parameters)
        context.insert(invoice)
        context.insert(reserve)
        context.insert(snapshot)
        context.insert(movement)
        context.insert(deadline)
        context.insert(payment)
        context.insert(taxReturn)
        try context.save()

        let data = try AppBackupService.encodedBackup(context: context, now: date("2026-05-08"))
        let preview = try AppBackupService.preview(from: data)
        XCTAssertEqual(preview.totalRecords, 9)

        let deleted = try AppBackupService.deleteAllData(in: context)
        XCTAssertEqual(deleted.totalRecords, 9)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Invoice>()).count, 0)

        let restored = try AppBackupService.restoreBackup(from: data, into: context)
        XCTAssertEqual(restored.totalRecords, 9)

        let restoredInvoice = try XCTUnwrap(try context.fetch(FetchDescriptor<Invoice>()).first)
        let restoredReserve = try XCTUnwrap(try context.fetch(FetchDescriptor<ReserveEntry>()).first)
        let restoredPayment = try XCTUnwrap(try context.fetch(FetchDescriptor<TaxPayment>()).first)
        let restoredDeadline = try XCTUnwrap(try context.fetch(FetchDescriptor<TaxDeadline>()).first)

        XCTAssertEqual(restoredInvoice.id, invoice.id)
        XCTAssertEqual(restoredInvoice.client, "Cliente Backup")
        XCTAssertEqual(restoredInvoice.status, .paid)
        XCTAssertEqual(restoredReserve.invoiceId, invoice.id)
        XCTAssertEqual(restoredPayment.deadlineId, restoredDeadline.id)
        XCTAssertMoneyEqual(restoredPayment.coveredAmount, decimal("500"))
        XCTAssertEqual(try AppBackupService.currentSummary(context: context).totalRecords, 9)
    }

    func testInvalidBackupDoesNotEraseExistingData() throws {
        let container = try ModelContainer.accantonaContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(Invoice(number: "SAFE-001", client: "Cliente", amount: decimal("100")))
        try context.save()

        XCTAssertThrowsError(try AppBackupService.restoreBackup(from: Data("{}".utf8), into: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<Invoice>()).count, 1)
    }

    func testDemoScenarioEndToEndNumbers() throws {
        let container = try ModelContainer.accantonaContainer(inMemory: true)
        let context = ModelContext(container)
        SeedData.installDemoScenario(context: context)

        let parameters = try XCTUnwrap(try context.fetch(FetchDescriptor<TaxParameters>()).first)
        let invoices = try context.fetch(FetchDescriptor<Invoice>())
        let reserves = try context.fetch(FetchDescriptor<ReserveEntry>())
        let deadlines = try context.fetch(FetchDescriptor<TaxDeadline>()).sorted { $0.date < $1.date }
        let payments = try context.fetch(FetchDescriptor<TaxPayment>())
        let movements = try context.fetch(FetchDescriptor<TaxAccountMovement>())
        let snapshots = try context.fetch(FetchDescriptor<TaxAccountSnapshot>())
        let returns = try context.fetch(FetchDescriptor<TaxReturnSummary>())

        let invoice = try XCTUnwrap(invoices.first { $0.number == "E2E-001" })
        let reserve = try XCTUnwrap(reserves.first { $0.invoiceId == invoice.id })
        let june = try XCTUnwrap(deadlines.first { Calendar.current.component(.month, from: $0.date) == 6 })
        let november = try XCTUnwrap(deadlines.first { Calendar.current.component(.month, from: $0.date) == 11 })
        let payment = try XCTUnwrap(payments.first)
        let setup = try XCTUnwrap(try context.fetch(FetchDescriptor<AppSetup>()).first)

        XCTAssertEqual(setup.onboardingCompleted, true)
        XCTAssertEqual(payment.deadlineId, june.id)
        XCTAssertEqual(invoice.status, .paid)
        XCTAssertEqual(invoice.paidDate, date("2026-02-16"))
        XCTAssertMoneyEqual(TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: parameters).prudentialReserve, decimal("1101.16"))
        XCTAssertMoneyEqual(reserve.actualReservedAmount, decimal("500"))
        XCTAssertMoneyEqual(ReserveAccounting.missingAmount(for: reserve), decimal("601.16"))
        XCTAssertMoneyEqual(TaxAccountLedger.balance(snapshots: snapshots, movements: movements), decimal("635.14"))

        let juneProjection = DeadlineCoverageCalculator.projection(
            for: june,
            parameters: parameters,
            invoices: invoices,
            reserves: reserves,
            taxPayments: payments,
            snapshots: snapshots,
            movements: movements
        )
        XCTAssertMoneyEqual(juneProjection.paidByF24, decimal("7399.27"))
        XCTAssertMoneyEqual(juneProjection.remainingDue, decimal("0"))
        XCTAssertEqual(juneProjection.certaintyTitle, "Pagato")

        let novemberProjection = DeadlineCoverageCalculator.projection(
            for: november,
            parameters: parameters,
            invoices: invoices,
            reserves: reserves,
            taxPayments: payments,
            snapshots: snapshots,
            movements: movements,
            startingBalance: juneProjection.projectedBalance - juneProjection.remainingDue,
            fromDateExclusive: june.date
        )
        XCTAssertMoneyEqual(novemberProjection.margin, decimal("-3300.46"))

        let simulated = try XCTUnwrap(SimulatorCalculator.result(
            input: SimulationInput(
                newIncome: decimal("13500"),
                expectedIncomeDate: date("2026-10-15"),
                reserveRate: parameters.appliedReserveRate,
                includeExpectedInvoices: false,
                includeRecoveries: false,
                target: .november
            ),
            deadlines: deadlines,
            parameters: parameters,
            invoices: invoices,
            reserves: reserves,
            taxPayments: payments,
            snapshots: snapshots,
            movements: movements
        ))
        XCTAssertMoneyEqual(simulated.projection.margin, decimal("558.05"))
        XCTAssertMoneyEqual(simulated.availableAfterReserve, decimal("9040.33"))

        let taxReturn = try XCTUnwrap(returns.first { $0.taxPeriod == 2023 })
        XCTAssertMoneyEqual(taxReturn.revenues, decimal("41646"))
        XCTAssertMoneyEqual(taxReturn.grossIncome, decimal("32484"))
        XCTAssertMoneyEqual(taxReturn.deductedContributions, decimal("11598"))
        XCTAssertMoneyEqual(taxReturn.taxableNetIncome, decimal("20886"))
        XCTAssertMoneyEqual(taxReturn.substituteTaxDue, decimal("1044"))
        XCTAssertMoneyEqual(taxReturn.substituteTaxAdvancesPaid, decimal("1882"))
        XCTAssertMoneyEqual(taxReturn.substituteTaxBalanceOrCredit, decimal("-838"))
    }
}

private func decimal(_ value: String) -> Decimal {
    Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
}

private func date(_ value: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)!
}

private func XCTAssertMoneyEqual(_ actual: Decimal, _ expected: Decimal, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(actual.roundedMoney, expected.roundedMoney, file: file, line: line)
}
