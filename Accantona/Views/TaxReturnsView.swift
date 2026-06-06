import SwiftData
import SwiftUI

struct TaxReturnsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxReturnSummary.taxPeriod, order: .reverse) private var summaries: [TaxReturnSummary]
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]
    @Query(sort: \ReserveEntry.date, order: .reverse) private var reserves: [ReserveEntry]
    @Query(sort: \TaxPayment.paymentDate, order: .reverse) private var payments: [TaxPayment]

    @State private var editorSummary: TaxReturnSummary?
    @State private var isShowingEditor = false
    @State private var summaryToDelete: TaxReturnSummary?
    @State private var persistenceAlert: PersistenceAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Dichiarazioni",
                    subtitle: "Confronta stime Accantona, F24 pagati e dati ufficiali della dichiarazione dei redditi.",
                    symbol: "doc.text.magnifyingglass",
                    tint: AppColor.petrol
                )

                if summaries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 14) {
                        ForEach(summaries) { summary in
                            TaxReturnCard(
                                summary: summary,
                                comparison: TaxReturnCalculator.comparison(
                                    for: summary,
                                    invoices: invoices,
                                    reserves: reserves,
                                    payments: payments
                                )
                            ) {
                                editorSummary = summary
                                isShowingEditor = true
                            } onDelete: {
                                summaryToDelete = summary
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .navigationTitle("Dichiarazioni")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorSummary = nil
                    isShowingEditor = true
                } label: {
                    Label("Nuova dichiarazione", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            TaxReturnEditorSheet(summary: editorSummary)
        }
        .confirmationDialog("Eliminare questa dichiarazione?", isPresented: deleteDialogBinding) {
            Button("Elimina riepilogo", role: .destructive) {
                if let summaryToDelete {
                    modelContext.delete(summaryToDelete)
                    self.summaryToDelete = nil
                    do {
                        try Persistence.save(modelContext)
                    } catch {
                        persistenceAlert = PersistenceAlert(error)
                    }
                }
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Rimuoverò solo il riepilogo dichiarazione. Fatture, F24 e movimenti conto tasse restano invariati.")
        }
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
        .appBackground()
    }

    private var emptyState: some View {
        Panel(title: "Nessun riepilogo ufficiale", subtitle: "Quando inserisci una dichiarazione, Accantona mostra delta tra incassi, accantonamenti, F24 e quadro dichiarativo.", symbol: "doc.badge.plus", tint: AppColor.amber) {
            VStack(spacing: 12) {
                EmptyStateView(
                    symbol: "doc.text.magnifyingglass",
                    title: "Aggiungi la prima dichiarazione",
                    message: "Puoi partire dai dati reali 2023 oppure registrare solo imposta e saldo 2024, completando il quadro LM in seguito."
                )
                Button {
                    editorSummary = nil
                    isShowingEditor = true
                } label: {
                    Label("Nuova dichiarazione", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
            }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { summaryToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    summaryToDelete = nil
                }
            }
        )
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

struct TaxReturnCard: View {
    let summary: TaxReturnSummary
    let comparison: AnnualTaxComparison
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 18, tint: AppColor.petrol) {
            VStack(alignment: .leading, spacing: 12) {
                header
                officialNumbers
                comparisonPanel
                actions
            }
            .padding(14)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dichiarazione \(summary.declarationYear)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Periodo d'imposta \(summary.taxPeriod)")
                    .font(.title3.bold())
                BadgeStack {
                    StatusBadge("Da dichiarazione", symbol: "checkmark.seal.fill", color: AppColor.sage)
                    StatusBadge("Da F24", symbol: "doc.plaintext.fill", color: AppColor.petrol)
                    StatusBadge("Stimato", symbol: "function", color: AppColor.amber)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text("Saldo imposta")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                MoneyText(
                    value: summary.substituteTaxBalanceOrCredit,
                    style: .title3.weight(.bold),
                    color: summary.substituteTaxBalanceOrCredit < 0 ? AppColor.sage : AppColor.coral
                )
            }
        }
    }

    private var officialNumbers: some View {
        VStack(spacing: 0) {
            DetailRow(title: "Ricavi/compensi dichiarati", value: MoneyFormatting.money(summary.revenues))
            DetailRow(title: "Reddito lordo", value: MoneyFormatting.money(summary.grossIncome))
            DetailRow(title: "Contributi dedotti", value: MoneyFormatting.money(summary.deductedContributions))
            DetailRow(title: "Reddito netto imponibile", value: MoneyFormatting.money(summary.taxableNetIncome))
            DetailRow(title: "Imposta sostitutiva dovuta", value: MoneyFormatting.money(summary.substituteTaxDue))
            DetailRow(title: "INPS dovuta", value: MoneyFormatting.money(summary.inpsDue))
        }
        .background(.background.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var comparisonPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confronto Accantona")
                .font(.headline)
            VStack(spacing: 0) {
                DetailRow(title: "Incassi registrati", value: MoneyFormatting.money(comparison.registeredIncome))
                DetailRow(title: "Accantonamenti calcolati", value: MoneyFormatting.money(comparison.calculatedReserves))
                DetailRow(title: "F24 imposta", value: MoneyFormatting.money(comparison.f24TaxPaid))
                DetailRow(title: "F24 INPS", value: MoneyFormatting.money(comparison.f24InpsPaid))
                DetailRow(title: "Delta incassi vs dichiarazione", value: MoneyFormatting.money(comparison.incomeDelta))
                DetailRow(title: "Delta stima vs dichiarazione", value: MoneyFormatting.money(comparison.reserveVsDeclarationDelta))
                DetailRow(title: "Delta F24 vs dichiarazione", value: MoneyFormatting.money(comparison.f24VsDeclarationDelta))
            }
            .background(.background.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var actions: some View {
        HStack {
            Button {
                onEdit()
            } label: {
                Label("Modifica", systemImage: "pencil")
            }
            .secondaryActionStyle()

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Elimina", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .secondaryActionStyle()
            .accessibilityLabel("Elimina dichiarazione \(summary.taxPeriod)")
        }
    }
}

struct TaxReturnEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let summary: TaxReturnSummary?

    @State private var declarationYearText: String
    @State private var taxPeriodText: String
    @State private var revenuesText: String
    @State private var coefficientText: String
    @State private var grossIncomeText: String
    @State private var deductedContributionsText: String
    @State private var taxableNetIncomeText: String
    @State private var substituteTaxDueText: String
    @State private var substituteTaxAdvancesText: String
    @State private var substituteTaxBalanceText: String
    @State private var inpsDueText: String
    @State private var inpsAdvancesText: String
    @State private var inpsBalanceText: String
    @State private var notes: String
    @State private var persistenceAlert: PersistenceAlert?

    init(summary: TaxReturnSummary?) {
        self.summary = summary
        _declarationYearText = State(initialValue: "\(summary?.declarationYear ?? Calendar.current.component(.year, from: .now))")
        _taxPeriodText = State(initialValue: "\(summary?.taxPeriod ?? Calendar.current.component(.year, from: .now) - 1)")
        _revenuesText = State(initialValue: summary.map { MoneyFormatting.decimal($0.revenues) } ?? "")
        _coefficientText = State(initialValue: summary.map { MoneyFormatting.percentage($0.profitabilityCoefficient) } ?? "78%")
        _grossIncomeText = State(initialValue: summary.map { MoneyFormatting.decimal($0.grossIncome) } ?? "")
        _deductedContributionsText = State(initialValue: summary.map { MoneyFormatting.decimal($0.deductedContributions) } ?? "")
        _taxableNetIncomeText = State(initialValue: summary.map { MoneyFormatting.decimal($0.taxableNetIncome) } ?? "")
        _substituteTaxDueText = State(initialValue: summary.map { MoneyFormatting.decimal($0.substituteTaxDue) } ?? "")
        _substituteTaxAdvancesText = State(initialValue: summary.map { MoneyFormatting.decimal($0.substituteTaxAdvancesPaid) } ?? "")
        _substituteTaxBalanceText = State(initialValue: summary.map { MoneyFormatting.decimal($0.substituteTaxBalanceOrCredit) } ?? "")
        _inpsDueText = State(initialValue: summary.map { MoneyFormatting.decimal($0.inpsDue) } ?? "")
        _inpsAdvancesText = State(initialValue: summary.map { MoneyFormatting.decimal($0.inpsAdvancesPaid) } ?? "")
        _inpsBalanceText = State(initialValue: summary.map { MoneyFormatting.decimal($0.inpsBalanceOrCredit) } ?? "")
        _notes = State(initialValue: summary?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenIntro(
                        title: summary == nil ? "Nuova dichiarazione" : "Modifica dichiarazione",
                        subtitle: "Inserisci i dati ufficiali e confrontali con stime, accantonamenti e F24 già registrati.",
                        symbol: "doc.text.magnifyingglass",
                        tint: AppColor.petrol
                    )

                    quickExamples
                    periodPanel
                    lmPanel
                    taxPanel
                    inpsPanel
                    notesPanel
                }
                .padding(14)
            }
            .navigationTitle(summary == nil ? "Nuova" : "Modifica")
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

    private var canSave: Bool {
        Int(declarationYearText) != nil && Int(taxPeriodText) != nil
    }

    private var quickExamples: some View {
        Panel(title: "Esempi rapidi", subtitle: "Carica i valori reali disponibili e completali quando hai il quadro definitivo.", symbol: "wand.and.stars", tint: AppColor.amber) {
            HStack(spacing: 10) {
                Button {
                    applyExample2023()
                } label: {
                    Label("2023 reale", systemImage: "doc.badge.gearshape")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .secondaryActionStyle()

                Button {
                    applyExample2024()
                } label: {
                    Label("2024 parziale", systemImage: "doc.badge.clock")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .secondaryActionStyle()
            }
        }
    }

    private var periodPanel: some View {
        Panel(title: "Periodo", subtitle: "Anno dichiarazione e periodo d'imposta a cui si riferiscono i dati.", symbol: "calendar", tint: AppColor.petrol) {
            VStack(spacing: 14) {
                AppTextField(title: "Anno dichiarazione", placeholder: "2024", text: $declarationYearText, keyboard: .numberPad)
                AppTextField(title: "Periodo d'imposta", placeholder: "2023", text: $taxPeriodText, keyboard: .numberPad)
            }
        }
    }

    private var lmPanel: some View {
        Panel(title: "Quadro LM", subtitle: "Dati reddituali ufficiali della dichiarazione.", symbol: "sum", tint: AppColor.sage) {
            VStack(spacing: 14) {
                AppTextField(title: "Ricavi/compensi", placeholder: "0,00", text: $revenuesText, keyboard: .numbersAndPunctuation)
                AppTextField(title: "Coefficiente redditività", placeholder: "78%", text: $coefficientText, keyboard: .numbersAndPunctuation)
                AppTextField(title: "Reddito lordo", placeholder: "0,00", text: $grossIncomeText, keyboard: .numbersAndPunctuation)
                AppTextField(title: "Contributi dedotti", placeholder: "0,00", text: $deductedContributionsText, keyboard: .numbersAndPunctuation)
                AppTextField(title: "Reddito netto imponibile", placeholder: "0,00", text: $taxableNetIncomeText, keyboard: .numbersAndPunctuation)
            }
        }
    }

    private var taxPanel: some View {
        Panel(title: "Imposta sostitutiva", subtitle: "Dovuto, acconti già versati e saldo o credito finale.", symbol: "percent", tint: AppColor.amber) {
            VStack(spacing: 14) {
                AppTextField(title: "Imposta dovuta", placeholder: "0,00", text: $substituteTaxDueText, keyboard: .numbersAndPunctuation)
                AppTextField(title: "Acconti imposta versati", placeholder: "0,00", text: $substituteTaxAdvancesText, keyboard: .numbersAndPunctuation)
                AppTextField(title: "Saldo/credito imposta", placeholder: "0,00", text: $substituteTaxBalanceText, keyboard: .numbersAndPunctuation)
            }
        }
    }

    private var inpsPanel: some View {
        Panel(title: "INPS", subtitle: "Dati contributivi ufficiali o da completare appena disponibili.", symbol: "person.text.rectangle.fill", tint: AppColor.petrol) {
            VStack(spacing: 14) {
                AppTextField(title: "INPS dovuta", placeholder: "0,00", text: $inpsDueText, keyboard: .numbersAndPunctuation)
                AppTextField(title: "Acconti INPS", placeholder: "0,00", text: $inpsAdvancesText, keyboard: .numbersAndPunctuation)
                AppTextField(title: "Saldo/credito INPS", placeholder: "0,00", text: $inpsBalanceText, keyboard: .numbersAndPunctuation)
            }
        }
    }

    private var notesPanel: some View {
        Panel(title: "Note", subtitle: "Annota origine dei dati, quadro o controlli ancora aperti.", symbol: "note.text", tint: .secondary) {
            AppTextField(title: "Note", placeholder: "Opzionale", text: $notes)
        }
    }

    private func save() {
        let target = summary ?? TaxReturnSummary()
        target.declarationYear = Int(declarationYearText) ?? target.declarationYear
        target.taxPeriod = Int(taxPeriodText) ?? target.taxPeriod
        target.revenues = parseMoney(revenuesText)
        target.profitabilityCoefficient = parseCoefficient(coefficientText)
        target.grossIncome = parseMoney(grossIncomeText)
        target.deductedContributions = parseMoney(deductedContributionsText)
        target.taxableNetIncome = parseMoney(taxableNetIncomeText)
        target.substituteTaxDue = parseMoney(substituteTaxDueText)
        target.substituteTaxAdvancesPaid = parseMoney(substituteTaxAdvancesText)
        target.substituteTaxBalanceOrCredit = parseMoney(substituteTaxBalanceText)
        target.inpsDue = parseMoney(inpsDueText)
        target.inpsAdvancesPaid = parseMoney(inpsAdvancesText)
        target.inpsBalanceOrCredit = parseMoney(inpsBalanceText)
        target.notes = notes

        if summary == nil {
            modelContext.insert(target)
        }
        do {
            try Persistence.save(modelContext)
            dismiss()
        } catch {
            persistenceAlert = PersistenceAlert(error)
        }
    }

    private func parseMoney(_ text: String) -> Decimal {
        MoneyFormatting.parseDecimal(text).roundedMoney
    }

    private func parseCoefficient(_ text: String) -> Decimal {
        let value = MoneyFormatting.parseDecimal(text)
        return value > 1 ? value / 100 : value
    }

    private func applyExample2023() {
        declarationYearText = "2024"
        taxPeriodText = "2023"
        revenuesText = "41646"
        coefficientText = "78%"
        grossIncomeText = "32484"
        deductedContributionsText = "11598"
        taxableNetIncomeText = "20886"
        substituteTaxDueText = "1044"
        substituteTaxAdvancesText = "1882"
        substituteTaxBalanceText = "-838"
        inpsDueText = "0"
        inpsAdvancesText = "0"
        inpsBalanceText = "0"
        notes = "Dati reali 2023 inseriti manualmente."
    }

    private func applyExample2024() {
        declarationYearText = "2025"
        taxPeriodText = "2024"
        revenuesText = "0"
        coefficientText = "78%"
        grossIncomeText = "0"
        deductedContributionsText = "0"
        taxableNetIncomeText = "0"
        substituteTaxDueText = "1191"
        substituteTaxAdvancesText = "1044"
        substituteTaxBalanceText = "147"
        inpsDueText = "0"
        inpsAdvancesText = "0"
        inpsBalanceText = "0"
        notes = "Dati imposta 2024 disponibili; quadro LM completo da aggiungere dopo."
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
