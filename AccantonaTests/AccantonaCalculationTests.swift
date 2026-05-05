import XCTest
@testable import Accantona

final class AccantonaCalculationTests: XCTestCase {
    func testTaxCalculatorUsesConfiguredForfettarioRates() {
        let parameters = TaxParameters(year: 2026)
        let breakdown = TaxCalculator.reserveBreakdown(for: decimal("3333.34"), parameters: parameters)

        XCTAssertMoneyEqual(breakdown.theoreticalReserve, decimal("1067.82"))
        XCTAssertMoneyEqual(breakdown.prudentialReserve, decimal("1101.16"))
        XCTAssertMoneyEqual(breakdown.availableAfterReserve, decimal("2232.18"))
        XCTAssertEqual(breakdown.appliedRate, decimal("0.330346"))
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
        let movement = TaxAccountMovement(
            date: payment.paymentDate,
            amount: TaxPaymentAccounting.ledgerAmount(for: payment),
            kind: TaxPaymentAccounting.ledgerKind(for: payment),
            note: TaxPaymentAccounting.ledgerNote(for: payment),
            sourceId: payment.id
        )

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
