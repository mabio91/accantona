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
            VStack(alignment: .leading, spacing: 18) {
                ScreenIntro(
                    title: "Parametri fiscali",
                    subtitle: "Le aliquote restano modificabili e leggibili. Ogni nuova versione salva il tasso applicato agli accantonamenti futuri.",
                    symbol: "slider.horizontal.3",
                    tint: AppColor.petrol
                )

            if let current = parameters.first {
                    currentParametersCard(current)
                }

                editorCard
            }
            .padding(18)
        }
        .navigationTitle("Parametri fiscali")
        .appBackground()
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
        .onAppear {
            if let current = parameters.first {
                yearText = "\(current.year + 1)"
            } else {
                yearText = "\(Calendar.current.component(.year, from: .now))"
            }
        }
    }

    private func currentParametersCard(_ current: TaxParameters) -> some View {
        GlassSurface(cornerRadius: 24, tint: AppColor.mint) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Versione \(current.year)")
                            .font(.headline)
                        Text("Accantonamento applicato")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(MoneyFormatting.percentage(current.appliedReserveRate))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(AppColor.sage)
                }

                VStack(spacing: 10) {
                    ParameterRow(title: "Imposta sostitutiva", value: MoneyFormatting.percentage(current.substituteTaxRate), note: "Aliquota configurabile dall'utente.")
                    ParameterRow(title: "Coefficiente redditivita", value: MoneyFormatting.percentage(current.profitabilityCoefficient), note: "Applicato agli incassi.")
                    ParameterRow(title: "INPS Gestione Separata", value: MoneyFormatting.percentage(current.inpsRate), note: "Quota contributiva stimata.")
                    ParameterRow(title: "Margine prudenziale", value: MoneyFormatting.percentage(current.prudentialExtraRate), note: "Extra sul totale incassato.")
                    ParameterRow(title: "Soglia margine basso", value: MoneyFormatting.money(current.minimumMarginThreshold), note: "Usata per lo stato della copertura.")
                }
            }
            .padding(18)
        }
    }

    private var editorCard: some View {
        Panel(title: "Nuova versione", subtitle: "Valori percentuali espressi come 15, 78, 26,07 e 1.", symbol: "plus.forwardslash.minus", tint: AppColor.sage) {
            VStack(spacing: 14) {
                AppTextField(title: "Anno", placeholder: "2026", text: $yearText, keyboard: .numberPad)
                AppTextField(title: "Imposta sostitutiva", placeholder: "15", text: $substituteTaxRateText, keyboard: .decimalPad)
                AppTextField(title: "Coefficiente redditivita", placeholder: "78", text: $profitabilityText, keyboard: .decimalPad)
                AppTextField(title: "INPS Gestione Separata", placeholder: "26,07", text: $inpsText, keyboard: .decimalPad)
                AppTextField(title: "Margine prudenziale", placeholder: "1", text: $extraText, keyboard: .decimalPad)
                AppTextField(title: "Soglia margine minimo", placeholder: "250", text: $thresholdText, keyboard: .decimalPad)

                Button {
                    save()
                } label: {
                    Label("Salva parametri", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
    }

    private func save() {
        let year = Int(yearText) ?? Calendar.current.component(.year, from: .now)
        if let existing = parameters.first(where: { $0.year == year }) {
            existing.substituteTaxRate = parsePercent(substituteTaxRateText)
            existing.profitabilityCoefficient = parsePercent(profitabilityText)
            existing.inpsRate = parsePercent(inpsText)
            existing.prudentialExtraRate = parsePercent(extraText)
            existing.minimumMarginThreshold = parseDecimal(thresholdText)
        } else {
            modelContext.insert(TaxParameters(
                year: year,
                substituteTaxRate: parsePercent(substituteTaxRateText),
                profitabilityCoefficient: parsePercent(profitabilityText),
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

    private func parsePercent(_ text: String) -> Decimal {
        let value = parseDecimal(text)
        return value > 1 ? value / 100 : value
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
