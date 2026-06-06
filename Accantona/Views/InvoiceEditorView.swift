import SwiftData
import SwiftUI

struct InvoiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]

    @State private var number = ""
    @State private var client = ""
    @State private var project = ""
    @State private var description = ""
    @State private var amountText = ""
    @State private var stampDutyText = "2"
    @State private var issueDate = Date()
    @State private var expectedPaymentDate = Date()
    @State private var paidDate = Date()
    @State private var hasExpectedPaymentDate = true
    @State private var status: InvoiceStatus = .issued
    @State private var persistenceAlert: PersistenceAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Nuova fattura",
                    subtitle: "Bastano pochi dati per calcolare la quota da mettere da parte e quanto resta dell'incasso.",
                    symbol: "doc.badge.plus",
                    tint: AppColor.petrol
                )

                Panel(title: "Cliente e lavoro", subtitle: nil, symbol: "person.crop.square.fill", tint: AppColor.sage) {
                    VStack(spacing: 14) {
                        AppTextField(title: "Numero", placeholder: "12/2026", text: $number)
                        AppTextField(title: "Cliente", placeholder: "Nome cliente", text: $client)
                        AppTextField(title: "Contratto o progetto", placeholder: "Consulenza", text: $project)
                        AppTextField(title: "Descrizione", placeholder: "Opzionale", text: $description)
                    }
                }

                Panel(title: "Importi", subtitle: "Il bollo resta separato e non entra nella quota tasse/INPS.", symbol: "eurosign.circle.fill", tint: AppColor.petrol) {
                    VStack(spacing: 14) {
                        AppTextField(title: "Imponibile o incasso senza bollo", placeholder: "3333,34", text: $amountText, keyboard: .decimalPad)
                        AppTextField(title: "Bollo", placeholder: "2,00", text: $stampDutyText, keyboard: .decimalPad)
                    }
                }

                Panel(title: "Date e stato", subtitle: nil, symbol: "calendar.badge.clock", tint: AppColor.amber) {
                    VStack(spacing: 14) {
                        DatePicker("Emissione", selection: $issueDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        Toggle("Incasso previsto", isOn: $hasExpectedPaymentDate)
                        if hasExpectedPaymentDate {
                            DatePicker("Data prevista", selection: $expectedPaymentDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Stato")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Stato", selection: $status) {
                                ForEach(InvoiceStatus.allCases) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        if status == .paid {
                            DatePicker("Data incasso effettiva", selection: $paidDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                            Text("Alla conferma verrà generata una quota da trasferire in Accantonamenti.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if isDuplicateInvoice {
                    Panel(
                        title: "Fattura già presente",
                        subtitle: "Numero, cliente e data emissione coincidono con una fattura esistente.",
                        symbol: "exclamationmark.triangle.fill",
                        tint: AppColor.coral
                    ) {
                        EmptyView()
                    }
                }

                Button {
                    save()
                } label: {
                    Label("Salva fattura", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
                .disabled(!canSave)
            }
            .padding(14)
        }
        .navigationTitle("Nuova fattura")
        .appBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") { dismiss() }
            }
        }
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
    }

    private var canSave: Bool {
        !number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && parsedAmount.map { $0 > 0 } == true
        && parsedStampDuty != nil
        && !isDuplicateInvoice
    }

    private var parsedAmount: Decimal? {
        MoneyFormatting.parseDecimalOrNil(amountText)?.roundedMoney
    }

    private var parsedStampDuty: Decimal? {
        let trimmed = stampDutyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return MoneyFormatting.parseDecimalOrNil(trimmed)?.roundedMoney
    }

    private var isDuplicateInvoice: Bool {
        guard !number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let candidate = InvoiceDuplicateKey(number: number, client: client, issueDate: issueDate)
        return invoices.contains { InvoiceDuplicateKey(invoice: $0) == candidate }
    }

    private func save() {
        let effectivePaidDate = InvoiceAccounting.paidDate(for: status, selectedPaidDate: paidDate)
        let fiscalYear = InvoiceAccounting.fiscalYear(for: effectivePaidDate)
        let invoice = Invoice(
            number: number,
            client: client,
            project: project,
            description: description,
            issueDate: issueDate,
            expectedPaymentDate: hasExpectedPaymentDate ? expectedPaymentDate : nil,
            paidDate: effectivePaidDate,
            amount: parsedAmount ?? 0,
            stampDuty: parsedStampDuty ?? 0,
            status: status,
            managementYear: Calendar.current.component(.year, from: issueDate),
            fiscalYear: fiscalYear
        )
        modelContext.insert(invoice)

        if status == .paid,
           let parameter = TaxParameterResolver.parameter(forFiscalYear: fiscalYear, parameters: parameters) {
            let breakdown = TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: parameter)
            modelContext.insert(ReserveEntry(
                invoiceId: invoice.id,
                date: effectivePaidDate ?? .now,
                incomeAmount: invoice.amount,
                appliedRate: breakdown.appliedRate,
                theoreticalAmount: breakdown.theoreticalReserve,
                prudentialAmount: breakdown.prudentialReserve,
                status: .pending
            ))
        }

        do {
            try Persistence.save(modelContext)
            dismiss()
        } catch {
            persistenceAlert = PersistenceAlert(error)
        }
    }

    private var persistenceAlertBinding: Binding<Bool> {
        Binding(
            get: { persistenceAlert != nil },
            set: { isPresented in
                if !isPresented {
                    persistenceAlert = nil
                }
            }
        )
    }
}
