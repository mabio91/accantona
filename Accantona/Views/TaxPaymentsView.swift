import SwiftData
import SwiftUI

struct TaxPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxPayment.paymentDate, order: .reverse) private var payments: [TaxPayment]
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]

    @State private var editorPayment: TaxPayment?
    @State private var isShowingEditor = false
    @State private var paymentToDelete: TaxPayment?
    @State private var persistenceAlert: PersistenceAlert?

    private var totalCovered: Decimal {
        payments.reduce(Decimal(0)) { $0 + TaxPaymentAccounting.coveredAmount(for: $1) }
    }

    private var totalNetPaid: Decimal {
        payments.reduce(Decimal(0)) { $0 + $1.amountPaid }
    }

    private var totalCompensated: Decimal {
        payments.reduce(Decimal(0)) { $0 + $1.amountCompensated }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenIntro(
                    title: "F24 e versamenti",
                    subtitle: "Registra pagamenti certi, crediti compensati e importi gia coperti per separare stime e realta.",
                    symbol: "doc.plaintext.fill",
                    tint: AppColor.sage
                )

                summaryCard
                paymentsPanel
            }
            .padding(18)
        }
        .navigationTitle("F24")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorPayment = nil
                    isShowingEditor = true
                } label: {
                    Label("Nuovo F24", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            TaxPaymentEditorSheet(payment: editorPayment)
        }
        .confirmationDialog("Eliminare questo F24?", isPresented: deleteDialogBinding) {
            Button("Elimina F24", role: .destructive) {
                if let paymentToDelete {
                    delete(paymentToDelete)
                }
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text(deleteMessage)
        }
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
        .appBackground()
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { paymentToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    paymentToDelete = nil
                }
            }
        )
    }

    private var deleteMessage: String {
        guard let paymentToDelete else {
            return "Rimuovero anche il movimento collegato dalla cassa tasse."
        }
        return "Rimuovero anche il movimento collegato dalla cassa tasse: \(paymentToDelete.code)."
    }

    private var summaryCard: some View {
        GlassSurface(cornerRadius: 24, tint: AppColor.sage) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Pagamenti certi")
                            .font(.headline)
                        Text("Il debito F24 copre le scadenze; il netto pagato muove la cassa.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge("Dato certo", symbol: "checkmark.seal.fill", color: AppColor.sage)
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Coperto da F24")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        MoneyText(value: totalCovered, style: .title2.weight(.bold), color: AppColor.petrol)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("Netto pagato")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        MoneyText(value: totalNetPaid, style: .title2.weight(.bold), color: AppColor.coral)
                    }
                }

                DetailRow(title: "Crediti compensati", value: MoneyFormatting.money(totalCompensated))
            }
            .padding(18)
        }
    }

    private var paymentsPanel: some View {
        Panel(title: "Versamenti registrati", subtitle: payments.isEmpty ? "Aggiungi il primo F24 manuale quando hai un pagamento o una compensazione certa." : nil, symbol: "tray.full.fill", tint: AppColor.amber) {
            if payments.isEmpty {
                EmptyStateView(
                    symbol: "doc.badge.plus",
                    title: "Nessun F24 registrato",
                    message: "Inserisci saldo, acconti, INPS o crediti compensati. Le scadenze passeranno da stimato a dato F24 o pagato."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(payments) { payment in
                        TaxPaymentRow(payment: payment) {
                            editorPayment = payment
                            isShowingEditor = true
                        } onDelete: {
                            paymentToDelete = payment
                        }
                    }
                }
            }
        }
    }

    private func delete(_ payment: TaxPayment) {
        for movement in movements where movement.sourceId == payment.id {
            modelContext.delete(movement)
        }
        modelContext.delete(payment)
        paymentToDelete = nil
        do {
            try Persistence.save(modelContext)
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

struct TaxPaymentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]
    @Query(sort: \TaxDeadline.date) private var deadlines: [TaxDeadline]

    let payment: TaxPayment?

    @State private var date: Date
    @State private var taxYearText: String
    @State private var deadlineId: UUID?
    @State private var type: TaxPaymentType
    @State private var section: TaxPaymentSection
    @State private var code: String
    @State private var amountDebtText: String
    @State private var compensatedText: String
    @State private var netPaidText: String
    @State private var notes: String
    @State private var persistenceAlert: PersistenceAlert?

    init(payment: TaxPayment?) {
        self.payment = payment
        _date = State(initialValue: payment?.paymentDate ?? .now)
        _taxYearText = State(initialValue: "\(payment?.taxYear ?? Calendar.current.component(.year, from: .now) - 1)")
        _deadlineId = State(initialValue: payment?.deadlineId)
        _type = State(initialValue: payment?.type ?? .balance)
        _section = State(initialValue: payment?.section ?? .erario)
        _code = State(initialValue: payment?.code ?? "1790")
        _amountDebtText = State(initialValue: payment.map { MoneyFormatting.decimal($0.coveredAmount) } ?? "")
        _compensatedText = State(initialValue: payment.map { MoneyFormatting.decimal($0.amountCompensated) } ?? "0")
        _netPaidText = State(initialValue: payment.map { MoneyFormatting.decimal($0.amountPaid) } ?? "")
        _notes = State(initialValue: payment?.notes ?? "")
    }

    private var amountDebt: Decimal { MoneyFormatting.parseDecimal(amountDebtText).roundedMoney }
    private var amountCompensated: Decimal { MoneyFormatting.parseDecimal(compensatedText).roundedMoney }
    private var netPaid: Decimal { MoneyFormatting.parseDecimal(netPaidText).roundedMoney }
    private var validation: TaxPaymentAccounting.Validation? {
        TaxPaymentAccounting.validation(
            type: type,
            section: section,
            code: code,
            amountDebt: amountDebt,
            amountCompensated: amountCompensated,
            amountPaid: netPaid
        )
    }

    private var canSave: Bool {
        !(validation?.isBlocking ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenIntro(
                        title: payment == nil ? "Nuovo F24" : "Modifica F24",
                        subtitle: "Debito e crediti aggiornano la copertura delle scadenze; il netto pagato aggiorna il ledger.",
                        symbol: "doc.plaintext.fill",
                        tint: AppColor.sage
                    )

                    formPanel
                    effectPanel
                }
                .padding(18)
            }
            .navigationTitle(payment == nil ? "Nuovo F24" : "Modifica")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .disabled(!canSave)
                }
            }
            .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(persistenceAlert?.message ?? "")
            }
            .appBackground()
        }
    }

    private var formPanel: some View {
        Panel(title: "Dati F24", subtitle: "I codici ricorrenti vengono controllati senza bloccare inserimenti particolari.", symbol: "square.and.pencil", tint: AppColor.petrol) {
            VStack(spacing: 14) {
                DatePicker("Data pagamento", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(12)
                    .background(.background.opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                AppTextField(title: "Anno imposta", placeholder: "2025", text: $taxYearText, keyboard: .numberPad)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Scadenza collegata")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Scadenza collegata", selection: $deadlineId) {
                        Text("Nessuna").tag(UUID?.none)
                        ForEach(deadlines) { deadline in
                            Text("\(deadline.title) · \(deadline.date.formatted(date: .abbreviated, time: .omitted))")
                                .tag(Optional(deadline.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Tipo pagamento")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Tipo pagamento", selection: $type) {
                        ForEach(TaxPaymentType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Sezione")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Sezione", selection: $section) {
                        ForEach(TaxPaymentSection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                AppTextField(title: "Codice tributo o causale", placeholder: suggestedCode, text: $code)
                    .textInputAutocapitalization(.characters)
                AppTextField(title: "Importo debito", placeholder: "0,00", text: $amountDebtText, keyboard: .decimalPad)
                AppTextField(title: "Credito compensato", placeholder: "0,00", text: $compensatedText, keyboard: .decimalPad)
                AppTextField(title: "Netto pagato", placeholder: "0,00", text: $netPaidText, keyboard: .decimalPad)
                AppTextField(title: "Note", placeholder: "Opzionale", text: $notes)

                if let validation {
                    ValidationCard(validation: validation)
                }
            }
        }
    }

    private var effectPanel: some View {
        GlassSurface(cornerRadius: 22, tint: AppColor.sage) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StatusBadge(amountDebt > 0 ? "Dato certo" : "Da F24", symbol: "doc.plaintext.fill", color: AppColor.petrol)
                    Spacer()
                    StatusBadge(netPaid <= 0 ? "Credito" : "Pagato", symbol: netPaid <= 0 ? "plus.circle.fill" : "checkmark.circle.fill", color: netPaid <= 0 ? AppColor.sage : AppColor.coral)
                }
                DetailRow(title: "Copertura scadenze", value: MoneyFormatting.money(amountDebt))
                DetailRow(title: "Credito compensato", value: MoneyFormatting.money(amountCompensated))
                DetailRow(title: "Movimento cassa", value: MoneyFormatting.money(-netPaid))
            }
            .padding(16)
        }
    }

    private var suggestedCode: String {
        switch type {
        case .balance: "1790"
        case .firstAdvance: "1791"
        case .secondAdvance: "1792"
        case .stampDuty: "Bollo"
        case .other: section == .inps ? "7005/PXX" : "Codice"
        }
    }

    private func save() {
        let target = payment ?? TaxPayment(
            paymentDate: date,
            taxYear: Int(taxYearText) ?? Calendar.current.component(.year, from: .now) - 1,
            deadlineId: deadlineId,
            type: type,
            section: section,
            code: code,
            amountDebt: amountDebt,
            amountPaid: netPaid,
            amountCompensated: amountCompensated,
            notes: notes
        )

        target.paymentDate = date
        target.taxYear = Int(taxYearText) ?? target.taxYear
        target.deadlineId = deadlineId
        target.type = type
        target.section = section
        target.code = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        target.amountDebt = amountDebt
        target.amountCompensated = amountCompensated
        target.amountPaid = netPaid
        target.notes = notes

        if payment == nil {
            modelContext.insert(target)
        }
        upsertLedgerMovement(for: target)
        do {
            try Persistence.save(modelContext)
            dismiss()
        } catch {
            persistenceAlert = PersistenceAlert(error)
        }
    }

    private func upsertLedgerMovement(for payment: TaxPayment) {
        if let movement = movements.first(where: { $0.sourceId == payment.id }) {
            TaxPaymentAccounting.updateLedgerMovement(movement, for: payment)
        } else {
            modelContext.insert(TaxPaymentAccounting.makeLedgerMovement(for: payment))
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

struct ValidationCard: View {
    let validation: TaxPaymentAccounting.Validation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: validation.isBlocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(validation.isBlocking ? AppColor.coral : AppColor.amber)
            VStack(alignment: .leading, spacing: 3) {
                Text(validation.title)
                    .font(.subheadline.weight(.semibold))
                Text(validation.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background((validation.isBlocking ? AppColor.coral : AppColor.amber).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct TaxPaymentRow: View {
    let payment: TaxPayment
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isCredit: Bool {
        payment.amountPaid < 0
    }

    var body: some View {
        GlassSurface(cornerRadius: 18, tint: payment.section == .inps ? AppColor.petrol : AppColor.sage) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: payment.section == .inps ? "person.text.rectangle.fill" : "doc.text.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(AppColor.petrol.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(AppColor.petrol)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(payment.code.isEmpty ? payment.section.rawValue : payment.code)
                                .font(.headline)
                            StatusBadge(payment.type.rawValue, symbol: "doc.plaintext.fill", color: AppColor.petrol)
                        }
                        Text("\(payment.section.rawValue) · \(payment.paymentDate.formatted(date: .abbreviated, time: .omitted)) · anno \(payment.taxYear)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(isCredit ? "Credito" : "Pagato", symbol: isCredit ? "plus.circle.fill" : "checkmark.circle.fill", color: isCredit ? AppColor.sage : AppColor.coral)
                }

                VStack(spacing: 0) {
                    DetailRow(title: "Debito coperto", value: MoneyFormatting.money(TaxPaymentAccounting.coveredAmount(for: payment)))
                    DetailRow(title: "Credito compensato", value: MoneyFormatting.money(payment.amountCompensated))
                    DetailRow(title: "Netto pagato", value: MoneyFormatting.money(payment.amountPaid))
                }

                if !payment.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(payment.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        onEdit()
                    } label: {
                        Label("Modifica", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Elimina", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Elimina F24 \(payment.code)")
                }
            }
            .padding(15)
        }
    }
}
