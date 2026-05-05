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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenIntro(
                    title: "Scadenze",
                    subtitle: "Saldo attuale, F24, recuperi e incassi attesi entrano nella stessa previsione.",
                    symbol: "calendar.badge.clock",
                    tint: AppColor.petrol
                )

                if deadlines.isEmpty {
                    EmptyStateView(symbol: "calendar.badge.plus", title: "Nessuna scadenza", message: "Le scadenze di giugno e novembre vengono create al primo avvio.")
                } else {
                    VStack(spacing: 16) {
                        ForEach(timelineProjections) { projection in
                            SmartDeadlineCard(
                                projection: projection
                            )
                        }
                    }
                }
            }
            .padding(18)
        }
        .navigationTitle("Scadenze")
        .appBackground()
    }

    private var timelineProjections: [DeadlineCoverageProjection] {
        var startingBalance: Decimal?
        var previousDeadlineDate: Date?

        return deadlines.sorted { $0.date < $1.date }.map { deadline in
            let projection = DeadlineCoverageCalculator.projection(
                for: deadline,
                parameters: parameters.first,
                invoices: invoices,
                reserves: reserves,
                taxPayments: taxPayments,
                snapshots: snapshots,
                movements: movements,
                startingBalance: startingBalance,
                fromDateExclusive: previousDeadlineDate
            )
            startingBalance = projection.projectedBalance - projection.remainingDue
            previousDeadlineDate = deadline.date
            return projection
        }
    }
}

struct SmartDeadlineCard: View {
    let projection: DeadlineCoverageProjection

    var body: some View {
        GlassSurface(cornerRadius: 24, tint: projection.risk.color) {
            VStack(alignment: .leading, spacing: 16) {
                header
                coverageBar
                primaryNumbers
                forecastBreakdown
            }
            .padding(18)
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
                HStack(spacing: 8) {
                    StatusBadge(projection.certaintyTitle, symbol: projection.certaintySymbol, color: projection.certaintyColor)
                    StatusBadge(projection.risk.title, symbol: projection.risk.symbol, color: projection.risk.color)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text("Da pagare")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
                Text("Coperto")
                    .foregroundStyle(.secondary)
                MoneyText(value: projection.coveredAmount, style: .caption.weight(.semibold))
                Spacer()
                Text("Totale")
                    .foregroundStyle(.secondary)
                MoneyText(value: projection.grossAmount, style: .caption.weight(.semibold))
            }
            .font(.caption)
        }
    }

    private var primaryNumbers: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Saldo previsto alla data")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                MoneyText(value: projection.projectedBalance, style: .title2.weight(.bold), color: AppColor.petrol)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(projection.margin >= 0 ? "Avanzo" : "Deficit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                MoneyText(value: projection.margin, style: .title2.weight(.bold), color: projection.margin >= 0 ? AppColor.sage : AppColor.coral)
            }
        }
    }

    private var forecastBreakdown: some View {
        VStack(spacing: 0) {
            DetailRow(title: "Saldo di partenza", value: MoneyFormatting.money(projection.currentBalance))
            DetailRow(title: "F24 gia registrati", value: MoneyFormatting.money(projection.paidByF24))
            DetailRow(title: "Residuo scadenza", value: MoneyFormatting.money(projection.remainingDue))
            DetailRow(title: "Recuperi accantonamenti", value: MoneyFormatting.money(projection.recoverableReserves))
            DetailRow(title: "Incassi attesi", value: MoneyFormatting.money(projection.futureIncome))
            DetailRow(title: "Accantonamenti futuri", value: MoneyFormatting.money(projection.futureReserves))
        }
        .background(.background.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
