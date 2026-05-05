import SwiftData
import SwiftUI

struct InvoiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]

    @State private var number = ""
    @State private var client = ""
    @State private var project = ""
    @State private var description = ""
    @State private var amountText = ""
    @State private var stampDutyText = "2"
    @State private var issueDate = Date()
    @State private var expectedPaymentDate = Date()
    @State private var hasExpectedPaymentDate = true
    @State private var status: InvoiceStatus = .issued

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenIntro(
                    title: "Nuova fattura",
                    subtitle: "Bastano pochi dati per vedere subito accantonamento e disponibile davvero.",
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

                Panel(title: "Importi", subtitle: "Usa virgola o punto per i decimali.", symbol: "eurosign.circle.fill", tint: AppColor.petrol) {
                    VStack(spacing: 14) {
                        AppTextField(title: "Importo incassato o imponibile", placeholder: "3333,34", text: $amountText, keyboard: .decimalPad)
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
                    }
                    .padding(12)
                    .background(.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    save()
                } label: {
                    Label("Salva fattura", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSave)
            }
            .padding(18)
        }
        .navigationTitle("Nuova fattura")
        .appBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") { dismiss() }
            }
        }
    }

    private var canSave: Bool {
        !number.trimmingCharacters(in: .whitespaces).isEmpty
        && !client.trimmingCharacters(in: .whitespaces).isEmpty
        && parseDecimal(amountText) > 0
    }

    private func save() {
        let paidDate = status == .paid ? Date() : nil
        let fiscalYear = paidDate.map { Calendar.current.component(.year, from: $0) }
        let invoice = Invoice(
            number: number,
            client: client,
            project: project,
            description: description,
            issueDate: issueDate,
            expectedPaymentDate: hasExpectedPaymentDate ? expectedPaymentDate : nil,
            paidDate: paidDate,
            amount: MoneyFormatting.parseDecimal(amountText).roundedMoney,
            stampDuty: MoneyFormatting.parseDecimal(stampDutyText).roundedMoney,
            status: status,
            managementYear: Calendar.current.component(.year, from: issueDate),
            fiscalYear: fiscalYear
        )
        modelContext.insert(invoice)

        if status == .paid, let parameter = parameters.first {
            let breakdown = TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: parameter)
            modelContext.insert(ReserveEntry(
                invoiceId: invoice.id,
                date: paidDate ?? .now,
                incomeAmount: invoice.amount,
                appliedRate: breakdown.appliedRate,
                theoreticalAmount: breakdown.theoreticalReserve,
                prudentialAmount: breakdown.prudentialReserve,
                status: .pending
            ))
        }

        try? modelContext.save()
        dismiss()
    }

    private func parseDecimal(_ text: String) -> Decimal { MoneyFormatting.parseDecimal(text) }
}
