import SwiftData
import SwiftUI

struct SimulatorView: View {
    @Query(sort: \TaxDeadline.date) private var deadlines: [TaxDeadline]
    @Query(sort: \TaxAccountSnapshot.updatedAt, order: .reverse) private var snapshots: [TaxAccountSnapshot]
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]
    @Query(sort: \ReserveEntry.date, order: .reverse) private var reserves: [ReserveEntry]
    @Query(sort: \TaxPayment.paymentDate, order: .reverse) private var taxPayments: [TaxPayment]

    @State private var incomeText = ""
    @State private var reserveRateText = ""
    @State private var expectedIncomeDate = Date()
    @State private var includeExpectedInvoices = true
    @State private var includeRecoveries = true
    @State private var selectedTarget: SimulatorTarget = .november

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Simulatore",
                    subtitle: "Prova incassi, recuperi e scadenze senza toccare i dati reali.",
                    symbol: "function",
                    tint: AppColor.petrol
                )

                controlsPanel

                if let result {
                    SimulatorResultCard(result: result, reserveRate: reserveRate)
                } else {
                    EmptyStateView(
                        symbol: "calendar.badge.exclamationmark",
                        title: "Nessuna scadenza simulabile",
                        message: "Aggiungi almeno una scadenza di giugno o novembre per vedere lo scenario."
                    )
                }
            }
            .padding(14)
        }
        .navigationTitle("Simulatore")
        .appBackground()
        .onAppear {
            if reserveRateText.isEmpty {
                reserveRateText = percentInput(for: defaultReserveRate)
            }
        }
    }

    private var controlsPanel: some View {
        Panel(title: "Scenario", subtitle: "Modifica un valore e il risultato si aggiorna subito.", symbol: "slider.horizontal.3", tint: AppColor.amber) {
            VStack(spacing: 14) {
                AppTextField(
                    title: "Nuovo incasso atteso",
                    placeholder: "13.500,00",
                    text: $incomeText,
                    keyboard: .decimalPad
                )

                DatePicker("Data prevista incasso", selection: $expectedIncomeDate, displayedComponents: .date)
                    .font(.subheadline.weight(.semibold))
                    .padding(12)
                    .background(.background.opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                AppTextField(
                    title: "Percentuale da accantonare",
                    placeholder: percentInput(for: defaultReserveRate),
                    text: $reserveRateText,
                    keyboard: .decimalPad
                )

                targetPicker

                Toggle("Includi altre fatture attese gia in app", isOn: $includeExpectedInvoices)
                    .toggleStyle(.switch)
                Toggle("Includi quote arretrate da recuperare", isOn: $includeRecoveries)
                    .toggleStyle(.switch)
            }
        }
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scadenza obiettivo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(SimulatorTarget.allCases) { target in
                    Button {
                        withAnimation(.snappy) {
                            selectedTarget = target
                        }
                    } label: {
                        Label(target.rawValue, systemImage: target.symbol)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(target == selectedTarget ? AppColor.petrol : AppColor.petrol.opacity(0.12), in: Capsule())
                            .foregroundStyle(target == selectedTarget ? .white : AppColor.petrol)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var result: SimulationResult? {
        SimulatorCalculator.result(
            input: SimulationInput(
                newIncome: newIncome,
                expectedIncomeDate: expectedIncomeDate,
                reserveRate: reserveRate,
                includeExpectedInvoices: includeExpectedInvoices,
                includeRecoveries: includeRecoveries,
                target: selectedTarget
            ),
            deadlines: deadlines,
            parameters: currentParameter,
            invoices: invoices,
            reserves: reserves,
            taxPayments: taxPayments,
            snapshots: snapshots,
            movements: movements
        )
    }

    private var newIncome: Decimal {
        parseDecimal(incomeText)
    }

    private var reserveRate: Decimal {
        let parsed = parseDecimal(reserveRateText)
        guard parsed > 0 else { return defaultReserveRate }
        return parsed > 1 ? parsed / 100 : parsed
    }

    private var defaultReserveRate: Decimal {
        currentParameter?.appliedReserveRate ?? Decimal(string: "0.330346")!
    }

    private var currentParameter: TaxParameters? {
        TaxParameterResolver.currentParameter(parameters: parameters)
    }

    private func percentInput(for value: Decimal) -> String {
        NSDecimalNumber(decimal: value * 100).stringValue.replacingOccurrences(of: ".", with: ",")
    }

    private func parseDecimal(_ text: String) -> Decimal {
        let compact = text
            .replacingOccurrences(of: "€", with: "")
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
}

struct SimulatorResultCard: View {
    let result: SimulationResult
    let reserveRate: Decimal

    var body: some View {
        GlassSurface(cornerRadius: 20, tint: result.statusColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        StatusBadge(result.statusTitle, symbol: result.isCovered ? "checkmark.seal.fill" : "xmark.octagon.fill", color: result.statusColor)
                        Text(result.resultMessage)
                            .font(.title3.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(result.targetDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(result.targetTitle)
                            .font(.headline)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.projection.margin >= 0 ? "Avanzo dopo scadenza" : "Scoperto dopo scadenza")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        MoneyText(value: result.projection.margin, style: .system(size: 26, weight: .bold, design: .rounded), color: result.statusColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("Percentuale accantonata")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                        Text(MoneyFormatting.percentage(reserveRate))
                            .font(.title3.bold())
                            .foregroundStyle(AppColor.petrol)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    SimulationMetricTile(
                        title: "Incassi necessari",
                        value: MoneyFormatting.money(result.requiredIncomeToCoverDeficit),
                        subtitle: result.requiredIncomeToCoverDeficit > 0 ? "per coprire lo scoperto" : "non servono altri incassi",
                        symbol: "arrow.up.forward.circle.fill",
                        tint: result.requiredIncomeToCoverDeficit > 0 ? AppColor.coral : AppColor.sage
                    )
                    SimulationMetricTile(
                        title: "Quota rinviabile",
                        value: MoneyFormatting.money(result.skippableAmount),
                        subtitle: "senza scendere sotto zero",
                        symbol: "minus.circle.fill",
                        tint: AppColor.amber
                    )
                    SimulationMetricTile(
                        title: "Resta del nuovo incasso",
                        value: MoneyFormatting.money(result.availableAfterReserve),
                        subtitle: "dopo accantonamento",
                        symbol: "wallet.pass.fill",
                        tint: AppColor.sage
                    )
                    SimulationMetricTile(
                        title: "Saldo conto tasse previsto",
                        value: MoneyFormatting.money(result.projection.projectedBalance),
                        subtitle: "alla scadenza",
                        symbol: "calendar.badge.clock",
                        tint: AppColor.petrol
                    )
                }
            }
            .padding(14)
        }
    }
}

struct SimulationMetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
