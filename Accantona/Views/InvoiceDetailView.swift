import SwiftData
import SwiftUI

struct InvoiceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]
    @Query(sort: \ReserveEntry.date, order: .reverse) private var reserves: [ReserveEntry]
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]
    @Bindable var invoice: Invoice
    @State private var showingPaidConfirmation = false
    @State private var showingPaidDateSheet = false
    @State private var paidDateDraft = Date()
    @State private var createdReserve: ReserveEntry?
    @State private var showingDeleteConfirmation = false
    @State private var persistenceAlert: PersistenceAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if let breakdown {
                    ReserveBreakdownView(breakdown: breakdown)
                }

                detailRows

                if invoice.status != .paid {
                    Button {
                        preparePaidRegistration()
                    } label: {
                        Label("Segna come incassata", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle()
                }
            }
            .padding(14)
        }
        .navigationTitle(invoice.number)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Elimina fattura")
            }
        }
        .confirmationDialog("Eliminare questa fattura?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Elimina fattura e dati collegati", role: .destructive) {
                deleteInvoice()
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Verranno rimosse anche le quote e i movimenti conto tasse creati da questa fattura.")
        }
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
        .appBackground()
        .sheet(isPresented: $showingPaidDateSheet) {
            PaidDateSheet(
                paidDate: $paidDateDraft,
                onConfirm: { date in
                    showingPaidDateSheet = false
                    markAsPaid(on: date)
                }
            )
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showingPaidConfirmation) {
            if let breakdown, let createdReserve {
                PaidConfirmationView(
                    breakdown: breakdown,
                    onReserveAll: {
                        markReserveTransferred(createdReserve, amount: createdReserve.prudentialAmount - createdReserve.actualReservedAmount)
                        showingPaidConfirmation = false
                    },
                    onReservePartial: { amount in
                        markReserveTransferred(createdReserve, amount: amount)
                        showingPaidConfirmation = false
                    },
                    onLater: {
                        showingPaidConfirmation = false
                    }
                )
                    .presentationDetents([.medium])
            }
        }
    }

    private var breakdown: ReserveBreakdown? {
        guard let parameter = TaxParameterResolver.parameter(for: invoice, parameters: parameters) else { return nil }
        return TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: parameter)
    }

    private var header: some View {
        GlassSurface(cornerRadius: 18, tint: AppColor.mint) {
            VStack(alignment: .leading, spacing: 10) {
                Text(invoice.client)
                    .font(.title3.bold())
                Text(invoice.project.isEmpty ? invoice.invoiceDescription : invoice.project)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                MoneyText(value: invoice.amount, style: .system(size: 30, weight: .bold, design: .rounded), color: AppColor.ink)
                StatusBadge(invoice.status.rawValue, symbol: invoice.status == .paid ? "checkmark.seal.fill" : "clock.fill", color: invoice.status == .paid ? AppColor.sage : AppColor.amber)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            DetailRow(title: "Emissione", value: invoice.issueDate.formatted(date: .abbreviated, time: .omitted))
            if let expected = invoice.expectedPaymentDate {
                DetailRow(title: "Incasso previsto", value: expected.formatted(date: .abbreviated, time: .omitted))
            }
            if let paid = invoice.paidDate {
                DetailRow(title: "Incasso effettivo", value: paid.formatted(date: .abbreviated, time: .omitted))
            }
            DetailRow(title: "Bollo", value: MoneyFormatting.money(invoice.stampDuty))
            DetailRow(title: "Anno gestione", value: "\(invoice.managementYear)")
            DetailRow(title: "Anno fiscale incasso", value: invoice.fiscalYear.map(String.init) ?? "Non incassata")
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func preparePaidRegistration() {
        paidDateDraft = invoice.expectedPaymentDate ?? invoice.paidDate ?? Date()
        showingPaidDateSheet = true
    }

    private func markAsPaid(on paidDate: Date) {
        let year = Calendar.current.component(.year, from: paidDate)
        guard let parameter = TaxParameterResolver.parameter(forFiscalYear: year, parameters: parameters) else { return }
        let breakdown = TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: parameter)
        let existingReserve = reserves.first(where: { $0.invoiceId == invoice.id })

        invoice.status = .paid
        invoice.paidDate = paidDate
        invoice.fiscalYear = year

        guard existingReserve == nil else {
            _ = saveChanges()
            return
        }

        let reserve = ReserveEntry(
            invoiceId: invoice.id,
            date: paidDate,
            incomeAmount: invoice.amount,
            appliedRate: breakdown.appliedRate,
            theoreticalAmount: breakdown.theoreticalReserve,
            prudentialAmount: breakdown.prudentialReserve,
            status: .pending
        )
        modelContext.insert(reserve)
        createdReserve = reserve
        guard saveChanges() else { return }
        showingPaidConfirmation = true
    }

    private func markReserveTransferred(_ reserve: ReserveEntry, amount: Decimal) {
        guard let plan = ReserveAccounting.planTransfer(for: reserve, requestedAmount: amount) else { return }
        ReserveAccounting.apply(plan, to: reserve)

        modelContext.insert(TaxAccountMovement(
            amount: plan.amount,
            kind: "Accantonamento",
            note: "Fattura \(invoice.number) · \(invoice.client)",
            sourceId: reserve.id
        ))
        _ = saveChanges()
    }

    private func deleteInvoice() {
        let linkedReserves = reserves.filter { $0.invoiceId == invoice.id }
        let linkedReserveIds = Set(linkedReserves.map(\.id))
        for movement in movements where movement.sourceId.map({ linkedReserveIds.contains($0) }) == true {
            modelContext.delete(movement)
        }
        for reserve in linkedReserves {
            modelContext.delete(reserve)
        }
        modelContext.delete(invoice)
        _ = saveChanges()
    }

    @discardableResult
    private func saveChanges() -> Bool {
        do {
            try Persistence.save(modelContext)
            return true
        } catch {
            persistenceAlert = PersistenceAlert(error)
            return false
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

struct PaidDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var paidDate: Date
    let onConfirm: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.secondary.opacity(0.28))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
            Text("Data incasso")
                .font(.headline)
            Text("Serve per assegnare l'incasso all'anno fiscale corretto e scegliere l'aliquota giusta.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DatePicker("Incassata il", selection: $paidDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(12)
                .background(.background.opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                onConfirm(paidDate)
                dismiss()
            } label: {
                Label("Registra incasso", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
        }
        .padding(16)
        .appBackground()
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .font(.subheadline)
        .padding(14)
    }
}

struct PaidConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let breakdown: ReserveBreakdown
    let onReserveAll: () -> Void
    let onReservePartial: (Decimal) -> Void
    let onLater: () -> Void
    @State private var partialAmountText = ""
    @State private var isShowingPartial = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.secondary.opacity(0.28))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
            Text("Incasso registrato")
                .font(.title3.bold())
            ReserveBreakdownView(breakdown: breakdown)

            if isShowingPartial {
                AppTextField(
                    title: "Importo trasferito sul conto tasse",
                    placeholder: MoneyFormatting.money(breakdown.prudentialReserve.roundedMoney),
                    text: $partialAmountText,
                    keyboard: .decimalPad
                )
            }

            VStack(spacing: 10) {
                Button {
                    if isShowingPartial {
                        onReservePartial(parseDecimal(partialAmountText))
                        dismiss()
                    } else {
                        onReserveAll()
                        dismiss()
                    }
                } label: {
                    Label(isShowingPartial ? "Segna parte accantonata" : "Segna accantonato", systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
                .disabled(isShowingPartial && parseDecimal(partialAmountText) <= 0)

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) {
                            isShowingPartial.toggle()
                        }
                    } label: {
                        Label(isShowingPartial ? "Tutto" : "Solo una parte", systemImage: "percent")
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryActionStyle()

                    Button {
                        onLater()
                        dismiss()
                    } label: {
                        Label("Piu tardi", systemImage: "clock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryActionStyle()
                }
            }
        }
        .padding(16)
        .appBackground()
    }

    private func parseDecimal(_ text: String) -> Decimal {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}
