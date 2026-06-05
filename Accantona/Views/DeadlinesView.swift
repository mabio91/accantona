import SwiftData
import SwiftUI

struct DeadlinesView: View {
    @Query(sort: \TaxDeadline.date) private var deadlines: [TaxDeadline]
    @Query(sort: \TaxAccountSnapshot.updatedAt, order: .reverse) private var snapshots: [TaxAccountSnapshot]
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]
    @Query(sort: \ReserveEntry.date, order: .reverse) private var reserves: [ReserveEntry]
    @Query(sort: \TaxPayment.paymentDate, order: .reverse) private var taxPayments: [TaxPayment]

    @State private var editorDeadline: TaxDeadline?
    @State private var isShowingEditor = false
    @State private var persistenceAlert: PersistenceAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Scadenze",
                    subtitle: "Per ogni data vedi cosa e gia coperto, cosa resta da pagare e il saldo previsto dopo il pagamento.",
                    symbol: "calendar.badge.clock",
                    tint: AppColor.petrol
                )

                if deadlines.isEmpty {
                    EmptyStateView(symbol: "calendar.badge.plus", title: "Nessuna scadenza", message: "Le scadenze di giugno e novembre vengono create al primo avvio.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(timelineProjections) { projection in
                            SmartDeadlineCard(
                                projection: projection,
                                onEdit: {
                                    editorDeadline = projection.deadline
                                    isShowingEditor = true
                                }
                            )
                        }
                    }
                }
            }
            .padding(14)
        }
        .navigationTitle("Scadenze")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorDeadline = nil
                    isShowingEditor = true
                } label: {
                    Label("Nuova scadenza", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            DeadlineEditorSheet(deadline: editorDeadline)
        }
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
        .appBackground()
    }

    private var timelineProjections: [DeadlineCoverageProjection] {
        var startingBalance: Decimal?
        var previousDeadlineDate: Date?

        return deadlines.sorted { $0.date < $1.date }.map { deadline in
            let projection = DeadlineCoverageCalculator.projection(
                for: deadline,
                parameters: TaxParameterResolver.currentParameter(parameters: parameters),
                invoices: invoices,
                reserves: reserves,
                taxPayments: taxPayments,
                snapshots: snapshots,
                movements: movements,
                parameterCatalog: parameters,
                startingBalance: startingBalance,
                fromDateExclusive: previousDeadlineDate
            )
            startingBalance = projection.projectedBalance - projection.remainingDue
            previousDeadlineDate = deadline.date
            return projection
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

struct SmartDeadlineCard: View {
    let projection: DeadlineCoverageProjection
    let onEdit: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 18, tint: projection.risk.color) {
            VStack(alignment: .leading, spacing: 12) {
                header
                coverageBar
                primaryNumbers
                forecastBreakdown
                Button {
                    onEdit()
                } label: {
                    Label("Modifica scadenza", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionStyle()
            }
            .padding(14)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(projection.deadline.date.formatted(date: .long, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(projection.deadline.title)
                    .font(.title3.bold())
                BadgeStack {
                    StatusBadge(projection.certaintyTitle, symbol: projection.certaintySymbol, color: projection.certaintyColor)
                    StatusBadge(projection.risk.title, symbol: projection.risk.symbol, color: projection.risk.color)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text("Importo scadenza")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                MoneyText(value: projection.grossAmount, style: .title3.weight(.bold))
            }
        }
    }

    private var coverageBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = CGFloat(truncating: projection.coverageRatio as NSDecimalNumber)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.16))
                    Capsule()
                        .fill(projection.risk.color)
                        .frame(width: max(8, width * progress))
                    Rectangle()
                        .fill(AppColor.ink.opacity(0.48))
                        .frame(width: 2)
                        .offset(x: max(0, width - 2))
                }
            }
            .frame(height: 12)

            HStack {
                Text("Gia coperto")
                    .foregroundStyle(.secondary)
                MoneyText(value: projection.coveredAmount, style: .caption.weight(.semibold))
                Spacer()
                Text("Importo scadenza")
                    .foregroundStyle(.secondary)
                MoneyText(value: projection.grossAmount, style: .caption.weight(.semibold))
            }
            .font(.caption)
        }
    }

    private var primaryNumbers: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Saldo conto tasse alla data")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                MoneyText(value: projection.projectedBalance, style: .title3.weight(.bold), color: AppColor.petrol)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(projection.margin >= 0 ? "Avanzo dopo pagamento" : "Scoperto dopo pagamento")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                MoneyText(value: projection.margin, style: .title3.weight(.bold), color: projection.margin >= 0 ? AppColor.sage : AppColor.coral)
            }
        }
    }

    private var forecastBreakdown: some View {
        VStack(spacing: 0) {
            DetailRow(title: "Saldo conto tasse iniziale", value: MoneyFormatting.money(projection.currentBalance))
            DetailRow(title: "Gia coperto da F24", value: MoneyFormatting.money(projection.paidByF24))
            DetailRow(title: "Ancora da pagare", value: MoneyFormatting.money(projection.remainingDue))
            DetailRow(title: "Quote arretrate recuperabili", value: MoneyFormatting.money(projection.recoverableReserves))
            DetailRow(title: "Nuovi incassi entro la data", value: MoneyFormatting.money(projection.futureIncome))
            DetailRow(title: "Quote da quei nuovi incassi", value: MoneyFormatting.money(projection.futureReserves))
        }
        .background(.background.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct DeadlineEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deadline: TaxDeadline?

    @State private var title: String
    @State private var date: Date
    @State private var taxYearText: String
    @State private var estimatedAmountText: String
    @State private var certainty: DeadlineCertainty
    @State private var notes: String
    @State private var persistenceAlert: PersistenceAlert?

    init(deadline: TaxDeadline?) {
        self.deadline = deadline
        _title = State(initialValue: deadline?.title ?? "")
        _date = State(initialValue: deadline?.date ?? .now)
        _taxYearText = State(initialValue: "\(deadline?.taxYear ?? Calendar.current.component(.year, from: .now))")
        _estimatedAmountText = State(initialValue: deadline.map { MoneyFormatting.decimal($0.estimatedAmount) } ?? "")
        _certainty = State(initialValue: deadline?.certainty ?? .estimate)
        _notes = State(initialValue: deadline?.notes ?? "")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && Int(taxYearText) != nil
        && MoneyFormatting.parseDecimal(estimatedAmountText) >= 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenIntro(
                        title: deadline == nil ? "Nuova scadenza" : "Modifica scadenza",
                        subtitle: "Importo, anno imposta e livello di certezza alimentano la copertura in dashboard.",
                        symbol: "calendar.badge.clock",
                        tint: AppColor.petrol
                    )

                    Panel(title: "Dati scadenza", subtitle: nil, symbol: "square.and.pencil", tint: AppColor.petrol) {
                        VStack(spacing: 12) {
                            AppTextField(title: "Titolo", placeholder: "Saldo + primo acconto", text: $title)
                            DatePicker("Data", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .padding(12)
                                .background(.background.opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            AppTextField(title: "Anno imposta", placeholder: "2026", text: $taxYearText, keyboard: .numberPad)
                            AppTextField(title: "Importo stimato o certo", placeholder: "0,00", text: $estimatedAmountText, keyboard: .decimalPad)

                            Picker("Certezza", selection: $certainty) {
                                ForEach(DeadlineCertainty.allCases, id: \.rawValue) { certainty in
                                    Text(certainty.rawValue).tag(certainty)
                                }
                            }
                            .pickerStyle(.segmented)

                            AppTextField(title: "Note", placeholder: "Origine importo o promemoria", text: $notes)
                        }
                    }
                }
                .padding(14)
            }
            .navigationTitle(deadline == nil ? "Nuova" : "Modifica")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: save)
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

    private func save() {
        let target = deadline ?? TaxDeadline(
            title: title,
            date: date,
            taxYear: Int(taxYearText) ?? Calendar.current.component(.year, from: .now),
            estimatedAmount: MoneyFormatting.parseDecimal(estimatedAmountText).roundedMoney
        )

        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.date = date
        target.taxYear = Int(taxYearText) ?? target.taxYear
        target.estimatedAmount = MoneyFormatting.parseDecimal(estimatedAmountText).roundedMoney
        target.certainty = certainty
        target.notes = notes

        if deadline == nil {
            modelContext.insert(target)
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
