import SwiftData
import SwiftUI

struct TaxParametersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]

    @State private var yearText = ""
    @State private var substituteTaxRateText = "15"
    @State private var profitabilityText = "78"
    @State private var inpsText = "26,07"
    @State private var extraText = "1"
    @State private var thresholdText = "250"
    @State private var persistenceAlert: PersistenceAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Parametri fiscali",
                    subtitle: "Qui decidi quale percentuale mettere da parte quando registri un nuovo incasso.",
                    symbol: "slider.horizontal.3",
                    tint: AppColor.petrol
                )

                if let current = displayedParameter {
                    currentParametersCard(current)
                }

                editorCard
            }
            .padding(14)
        }
        .navigationTitle("Parametri fiscali")
        .appBackground()
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
        .onAppear {
            if let current = displayedParameter {
                yearText = "\(current.year + 1)"
            } else {
                yearText = "\(Calendar.current.component(.year, from: .now))"
            }
        }
    }

    private var displayedParameter: TaxParameters? {
        TaxParameterResolver.currentParameter(parameters: parameters)
    }

    private func currentParametersCard(_ current: TaxParameters) -> some View {
        GlassSurface(cornerRadius: 18, tint: AppColor.mint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Versione \(current.year)")
                            .font(.headline)
                        Text("Percentuale da mettere da parte")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(MoneyFormatting.percentage(current.appliedReserveRate))
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(AppColor.sage)
                }

                VStack(spacing: 10) {
                    ParameterRow(title: "Imposta sostitutiva", value: MoneyFormatting.percentage(current.substituteTaxRate), note: "Aliquota configurabile dall'utente.")
                    ParameterRow(title: "Coefficiente redditività", value: MoneyFormatting.percentage(current.profitabilityCoefficient), note: "Parte dell'incasso su cui stimare imposte e INPS.")
                    ParameterRow(title: "INPS Gestione Separata", value: MoneyFormatting.percentage(current.inpsRate), note: "Quota contributiva stimata.")
                    ParameterRow(title: "Extra prudenziale", value: MoneyFormatting.percentage(current.prudentialExtraRate), note: "Piccola quota di sicurezza aggiunta al totale incassato.")
                    ParameterRow(title: "Soglia avanzo basso", value: MoneyFormatting.money(current.minimumMarginThreshold), note: "Sotto questa soglia una scadenza è segnalata come coperta ma stretta.")
                }
            }
            .padding(14)
        }
    }

    private var editorCard: some View {
        Panel(title: "Nuova versione", subtitle: "Inserisci le percentuali come 15, 78, 26,07 e 1.", symbol: "plus.forwardslash.minus", tint: AppColor.sage) {
            VStack(spacing: 14) {
                AppTextField(title: "Anno", placeholder: "2026", text: $yearText, keyboard: .numberPad)
                AppTextField(title: "Imposta sostitutiva", placeholder: "15", text: $substituteTaxRateText, keyboard: .decimalPad)
                AppTextField(title: "Coefficiente redditività", placeholder: "78", text: $profitabilityText, keyboard: .decimalPad)
                AppTextField(title: "INPS Gestione Separata", placeholder: "26,07", text: $inpsText, keyboard: .decimalPad)
                AppTextField(title: "Extra prudenziale", placeholder: "1", text: $extraText, keyboard: .decimalPad)
                AppTextField(title: "Soglia avanzo minimo", placeholder: "250", text: $thresholdText, keyboard: .decimalPad)

                Button {
                    save()
                } label: {
                    Label("Salva parametri", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
                .padding(.top, 4)
            }
        }
    }

    private func save() {
        let year = Int(yearText) ?? Calendar.current.component(.year, from: .now)
        if let existing = parameters.first(where: { $0.year == year }) {
            existing.substituteTaxRate = parsePercent(substituteTaxRateText)
            existing.profitabilityCoefficient = parsePercent(profitabilityText, allowsWhole: true)
            existing.inpsRate = parsePercent(inpsText)
            existing.prudentialExtraRate = parsePercent(extraText)
            existing.minimumMarginThreshold = parseDecimal(thresholdText)
        } else {
            modelContext.insert(TaxParameters(
                year: year,
                substituteTaxRate: parsePercent(substituteTaxRateText),
                profitabilityCoefficient: parsePercent(profitabilityText, allowsWhole: true),
                inpsRate: parsePercent(inpsText),
                prudentialExtraRate: parsePercent(extraText),
                minimumMarginThreshold: parseDecimal(thresholdText)
            ))
        }
        do {
            try Persistence.save(modelContext)
        } catch {
            persistenceAlert = PersistenceAlert(error)
        }
    }

    private func parsePercent(_ text: String, allowsWhole: Bool = false) -> Decimal {
        TaxParameterInputParser.percent(text, allowsWhole: allowsWhole)
    }

    private func parseDecimal(_ text: String) -> Decimal {
        MoneyFormatting.parseDecimal(text)
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

struct ParameterRow: View {
    let title: String
    let value: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
