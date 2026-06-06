import SwiftData
import SwiftUI

enum OnboardingMode {
    case firstRun
    case settings
}

private enum OnboardingStep: Int, CaseIterable {
    case intro
    case regime
    case parameters
    case balance
    case deadlines
    case firstInvoice
    case summary
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var setups: [AppSetup]
    @Query(sort: \TaxParameters.year, order: .reverse) private var existingParameters: [TaxParameters]
    @Query(sort: \TaxDeadline.date) private var existingDeadlines: [TaxDeadline]
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]

    let mode: OnboardingMode

    @State private var step: OnboardingStep = .intro
    @State private var regimeName = "Regime forfettario"
    @State private var substituteTaxRateText = "15"
    @State private var profitabilityCoefficientText = "78"
    @State private var inpsRateText = "26,07"
    @State private var prudentialExtraRateText = "1"
    @State private var initialBalanceText = ""
    @State private var createFirstInvoice = false
    @State private var invoiceNumber = ""
    @State private var invoiceClient = ""
    @State private var invoiceAmountText = ""
    @State private var invoiceExpectedDate = Date()
    @State private var persistenceAlert: PersistenceAlert?

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                progressHeader
                stepContent
                navigationBar
            }
            .padding(14)
        }
        .navigationTitle(mode == .firstRun ? "" : "Setup")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .onAppear(perform: loadExistingValues)
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Setup Accantona")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.petrol)
                Spacer()
                Text("\(step.rawValue + 1)/\(OnboardingStep.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let progress = CGFloat(step.rawValue + 1) / CGFloat(OnboardingStep.allCases.count)
                Capsule()
                    .fill(.secondary.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppColor.petrol)
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intro:
            introStep
        case .regime:
            regimeStep
        case .parameters:
            parametersStep
        case .balance:
            balanceStep
        case .deadlines:
            deadlinesStep
        case .firstInvoice:
            firstInvoiceStep
        case .summary:
            summaryStep
        }
    }

    private var introStep: some View {
        GlassSurface(cornerRadius: 20, tint: AppColor.mint) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppColor.sage)
                Text("Accantona")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Una cassa fiscale personale: imposti parametri, saldo e scadenze una volta, poi ogni incasso diventa una decisione chiara.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private var regimeStep: some View {
        OnboardingPanel(title: "Regime fiscale", subtitle: "Per ora Accantona nasce per il forfettario. Potrai modificare i parametri quando cambiano aliquote o anno fiscale.", symbol: "person.text.rectangle.fill", tint: AppColor.petrol) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    regimeName = "Regime forfettario"
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(AppColor.sage)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Regime forfettario")
                                .font(.headline)
                            Text("Imposta sostitutiva, coefficiente di redditività e INPS configurabili.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(AppColor.sage.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var parametersStep: some View {
        OnboardingPanel(title: "Parametri iniziali", subtitle: "Da questi valori Accantona calcola la percentuale da mettere da parte a ogni incasso.", symbol: "percent", tint: AppColor.amber) {
            VStack(spacing: 12) {
                AppTextField(title: "Imposta sostitutiva", placeholder: "15", text: $substituteTaxRateText, keyboard: .decimalPad)
                AppTextField(title: "Coefficiente redditività", placeholder: "78", text: $profitabilityCoefficientText, keyboard: .decimalPad)
                AppTextField(title: "INPS Gestione Separata", placeholder: "26,07", text: $inpsRateText, keyboard: .decimalPad)
                AppTextField(title: "Extra prudenziale", placeholder: "1", text: $prudentialExtraRateText, keyboard: .decimalPad)

                HStack {
                    Label("Percentuale da mettere da parte", systemImage: "equal.circle.fill")
                        .font(.headline)
                    Spacer()
                    Text(MoneyFormatting.percentage(appliedReserveRate))
                        .font(.title3.bold())
                        .foregroundStyle(AppColor.petrol)
                        .monospacedDigit()
                }
                .padding(14)
                .background(AppColor.petrol.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var balanceStep: some View {
        OnboardingPanel(title: "Saldo conto tasse", subtitle: "Inserisci quanto hai già sul conto dedicato alle tasse. Poi trasferimenti e F24 aggiorneranno il saldo.", symbol: "building.columns.fill", tint: AppColor.sage) {
            VStack(spacing: 12) {
                AppTextField(title: "Saldo iniziale", placeholder: "7.534,41", text: $initialBalanceText, keyboard: .decimalPad)
                DetailRow(title: "Movimento creato", value: MoneyFormatting.money(initialBalance.roundedMoney))
                    .background(.background.opacity(0.44), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var deadlinesStep: some View {
        OnboardingPanel(title: "Scadenze base", subtitle: "Creo le due scadenze fiscali principali dell'anno. Gli importi partono a zero se non li conosci ancora.", symbol: "calendar.badge.clock", tint: AppColor.petrol) {
            VStack(spacing: 10) {
                SetupPreviewRow(title: "Saldo + primo acconto", subtitle: "30 giugno \(currentYear)", symbol: "sun.max.fill", tint: AppColor.amber)
                SetupPreviewRow(title: "Secondo acconto", subtitle: "30 novembre \(currentYear)", symbol: "cloud.sun.fill", tint: AppColor.petrol)
            }
        }
    }

    private var firstInvoiceStep: some View {
        OnboardingPanel(title: "Prima fattura", subtitle: "Puoi aggiungerne una adesso oppure iniziare dalla dashboard.", symbol: "doc.text.fill", tint: AppColor.sage) {
            VStack(spacing: 12) {
                Toggle("Aggiungi una prima fattura", isOn: $createFirstInvoice)
                    .toggleStyle(.switch)

                if createFirstInvoice {
                    AppTextField(title: "Numero fattura", placeholder: "1/\(currentYear)", text: $invoiceNumber)
                    AppTextField(title: "Cliente", placeholder: "Nome cliente", text: $invoiceClient)
                    AppTextField(title: "Importo", placeholder: "3.333,34", text: $invoiceAmountText, keyboard: .decimalPad)
                    DatePicker("Incasso previsto", selection: $invoiceExpectedDate, displayedComponents: .date)
                        .font(.subheadline.weight(.semibold))
                        .padding(12)
                        .background(.background.opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var summaryStep: some View {
        GlassSurface(cornerRadius: 20, tint: AppColor.sage) {
            VStack(alignment: .leading, spacing: 12) {
                StatusBadge("Pronto", symbol: "checkmark.seal.fill", color: AppColor.sage)
                Text("Accantona è configurata")
                    .font(.title3.bold())

                VStack(spacing: 0) {
                    DetailRow(title: "Regime", value: regimeName)
                    DetailRow(title: "Percentuale da mettere da parte", value: MoneyFormatting.percentage(appliedReserveRate))
                    DetailRow(title: "Saldo iniziale conto tasse", value: MoneyFormatting.money(initialBalance.roundedMoney))
                    DetailRow(title: "Scadenze", value: "Giugno e novembre \(currentYear)")
                    DetailRow(title: "Prima fattura", value: createFirstInvoice ? MoneyFormatting.money(firstInvoiceAmount.roundedMoney) : "Saltata")
                }
                .background(.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(14)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button {
                previousStep()
            } label: {
                Label("Indietro", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .secondaryActionStyle()
            .disabled(step == .intro)

            Button {
                if step == .summary {
                    completeSetup()
                } else {
                    nextStep()
                }
            } label: {
                Label(step == .summary ? "Completa" : "Continua", systemImage: step == .summary ? "checkmark" : "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
        }
    }

    private var substituteTaxRate: Decimal { percentageValue(substituteTaxRateText, fallback: 0.15) }
    private var profitabilityCoefficient: Decimal { percentageValue(profitabilityCoefficientText, fallback: 0.78, allowsWhole: true) }
    private var inpsRate: Decimal { percentageValue(inpsRateText, fallback: 0.2607) }
    private var prudentialExtraRate: Decimal { percentageValue(prudentialExtraRateText, fallback: 0.01) }
    private var appliedReserveRate: Decimal {
        profitabilityCoefficient * (substituteTaxRate + inpsRate) + prudentialExtraRate
    }
    private var initialBalance: Decimal { parseDecimal(initialBalanceText) }
    private var firstInvoiceAmount: Decimal { parseDecimal(invoiceAmountText) }

    private func nextStep() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(.snappy) { step = next }
    }

    private func previousStep() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(.snappy) { step = previous }
    }

    private func loadExistingValues() {
        if let setup = setups.first {
            regimeName = setup.regimeName
        }

        if let parameters = existingParameters.first {
            substituteTaxRateText = percentInput(parameters.substituteTaxRate)
            profitabilityCoefficientText = percentInput(parameters.profitabilityCoefficient)
            inpsRateText = percentInput(parameters.inpsRate)
            prudentialExtraRateText = percentInput(parameters.prudentialExtraRate)
        }

        if initialBalanceText.isEmpty, let initialMovement = movements.first(where: { $0.kind == "Saldo iniziale" }) {
            initialBalanceText = NSDecimalNumber(decimal: initialMovement.amount).stringValue.replacingOccurrences(of: ".", with: ",")
        }
    }

    private func completeSetup() {
        let setup = upsertSetup()
        upsertParameters()
        upsertInitialBalanceMovement(setup: setup)
        upsertBaseDeadlines()
        insertFirstInvoiceIfNeeded()
        do {
            try Persistence.save(modelContext)
            dismiss()
        } catch {
            persistenceAlert = PersistenceAlert(error)
        }
    }

    private func upsertSetup() -> AppSetup {
        let setup = setups.first ?? AppSetup()
        setup.onboardingCompleted = true
        setup.completedAt = setup.completedAt ?? .now
        setup.updatedAt = .now
        setup.regimeName = regimeName
        if setups.isEmpty {
            modelContext.insert(setup)
        }
        return setup
    }

    private func upsertParameters() {
        let parameters = existingParameters.first(where: { $0.year == currentYear }) ?? TaxParameters(year: currentYear)
        parameters.substituteTaxRate = substituteTaxRate
        parameters.profitabilityCoefficient = profitabilityCoefficient
        parameters.inpsRate = inpsRate
        parameters.prudentialExtraRate = prudentialExtraRate
        if !existingParameters.contains(where: { $0.id == parameters.id }) {
            modelContext.insert(parameters)
        }
    }

    private func upsertInitialBalanceMovement(setup: AppSetup) {
        let amount = initialBalance.roundedMoney
        if let existing = movements.first(where: { $0.kind == "Saldo iniziale" }) {
            OnboardingAccounting.updateInitialBalanceMovement(existing, amount: amount, setup: setup)
        } else {
            modelContext.insert(OnboardingAccounting.makeInitialBalanceMovement(amount: amount, setup: setup))
        }
    }

    private func upsertBaseDeadlines() {
        let calendar = Calendar.current
        if let june = calendar.date(from: DateComponents(year: currentYear, month: 6, day: 30)) {
            insertDeadlineIfMissing(title: "Saldo + primo acconto", date: june, taxYear: currentYear - 1)
        }
        if let november = calendar.date(from: DateComponents(year: currentYear, month: 11, day: 30)) {
            insertDeadlineIfMissing(title: "Secondo acconto", date: november, taxYear: currentYear)
        }
    }

    private func insertDeadlineIfMissing(title: String, date: Date, taxYear: Int) {
        let calendar = Calendar.current
        let exists = existingDeadlines.contains { deadline in
            calendar.isDate(deadline.date, inSameDayAs: date) || deadline.title.lowercased() == title.lowercased()
        }
        guard !exists else { return }
        modelContext.insert(TaxDeadline(
            title: title,
            date: date,
            taxYear: taxYear,
            estimatedAmount: 0,
            certainty: .estimate,
            notes: "Creata dal setup iniziale"
        ))
    }

    private func insertFirstInvoiceIfNeeded() {
        guard createFirstInvoice, firstInvoiceAmount > 0 else { return }
        modelContext.insert(Invoice(
            number: invoiceNumber.isEmpty ? "1/\(currentYear)" : invoiceNumber,
            client: invoiceClient.isEmpty ? "Cliente" : invoiceClient,
            issueDate: .now,
            expectedPaymentDate: invoiceExpectedDate,
            amount: firstInvoiceAmount.roundedMoney,
            status: .issued,
            managementYear: currentYear,
            notes: "Creata dal setup iniziale"
        ))
    }

    private func percentageValue(_ text: String, fallback: Decimal, allowsWhole: Bool = false) -> Decimal {
        TaxParameterInputParser.percent(text, fallback: fallback, allowsWhole: allowsWhole)
    }

    private func percentInput(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value * 100).stringValue.replacingOccurrences(of: ".", with: ",")
    }

    private func parseDecimal(_ text: String) -> Decimal {
        let compact = text
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: " ", with: "")
        let normalized: String
        if compact.contains(",") {
            normalized = compact
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = compact
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) ?? 0
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

struct OnboardingPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        GlassSurface(cornerRadius: 18, tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                ScreenIntro(title: title, subtitle: subtitle, symbol: symbol, tint: tint)
                content
            }
            .padding(14)
        }
    }
}

struct SetupPreviewRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.sage)
        }
        .padding(13)
        .background(.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
