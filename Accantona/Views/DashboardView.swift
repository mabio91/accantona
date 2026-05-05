import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]
    @Query(sort: \ReserveEntry.date, order: .reverse) private var reserves: [ReserveEntry]
    @Query(sort: \TaxAccountSnapshot.updatedAt, order: .reverse) private var snapshots: [TaxAccountSnapshot]
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]
    @Query(sort: \TaxDeadline.date) private var deadlines: [TaxDeadline]
    @Query(sort: \TaxPayment.paymentDate, order: .reverse) private var taxPayments: [TaxPayment]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let parameters = currentParameters {
                    ReserveBreakdownView(
                        breakdown: TaxCalculator.reserveBreakdown(for: latestIncome, parameters: parameters)
                    )
                }

                if let projection = nextDeadlineProjection {
                    SmartDeadlineCard(projection: projection)
                }

                quickStats
                fiscalTimeline
                quickActions
            }
            .padding(18)
        }
        .navigationTitle("Accantona")
        .appBackground()
    }

    private var currentParameters: TaxParameters? {
        parameters.first
    }

    private var currentBalance: Decimal {
        TaxAccountLedger.balance(snapshots: snapshots, movements: movements)
    }

    private var latestIncome: Decimal {
        invoices.first(where: { $0.status == .paid })?.amount
            ?? invoices.first?.amount
            ?? 0
    }

    private var nextDeadline: TaxDeadline? {
        deadlines.first { $0.date >= Calendar.current.startOfDay(for: .now) } ?? deadlines.first
    }

    private var nextDeadlineProjection: DeadlineCoverageProjection? {
        guard let nextDeadline else { return nil }
        return DeadlineCoverageCalculator.projection(
            for: nextDeadline,
            parameters: currentParameters,
            invoices: invoices,
            reserves: reserves,
            taxPayments: taxPayments,
            snapshots: snapshots,
            movements: movements
        )
    }

    private var pendingReserveTotal: Decimal {
        reserves
            .filter { $0.status == .pending || $0.status == .partial || $0.status == .skipped }
            .reduce(Decimal(0)) { $0 + max($1.prudentialAmount - $1.actualReservedAmount, 0) }
    }

    private var paidInvoicesThisYear: Decimal {
        let year = Calendar.current.component(.year, from: .now)
        return invoices
            .filter { $0.status == .paid && ($0.fiscalYear ?? year) == year }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Oggi")
                .font(.largeTitle.bold())
            Text("Quando incassi, sai subito quanto mettere da parte.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickStats: some View {
        VStack(spacing: 10) {
            MetricRow(title: "Saldo conto tasse", value: currentBalance, symbol: "building.columns.fill", color: AppColor.petrol)
            MetricRow(title: "Da accantonare", value: pendingReserveTotal, symbol: "tray.and.arrow.down.fill", color: AppColor.amber)
            MetricRow(title: "Incassato quest'anno", value: paidInvoicesThisYear, symbol: "checkmark.circle.fill", color: AppColor.sage)
        }
    }

    private var fiscalTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline fiscale")
                .font(.headline)
            ForEach(deadlines.prefix(3)) { deadline in
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .frame(width: 32, height: 32)
                        .background(AppColor.petrol.opacity(0.12), in: Circle())
                        .foregroundStyle(AppColor.petrol)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deadline.title)
                            .font(.subheadline.weight(.semibold))
                        Text(deadline.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    MoneyText(value: deadline.estimatedAmount, style: .subheadline.weight(.semibold))
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                InvoiceEditorView()
            } label: {
                Label("Nuova fattura", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            NavigationLink {
                CashView()
            } label: {
                Label("Aggiorna saldo", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

struct MetricRow: View {
    let title: String
    let value: Decimal
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: Circle())
            Text(title)
                .font(.subheadline)
            Spacer()
            MoneyText(value: value, style: .headline)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct TaxDeadlineCard: View {
    let deadline: TaxDeadline
    let balance: Decimal
    let threshold: Decimal

    var body: some View {
        let result = TaxCalculator.coverage(required: deadline.estimatedAmount, available: balance, threshold: threshold)

        GlassSurface(cornerRadius: 24, tint: AppColor.petrol) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prossima scadenza")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(deadline.title)
                            .font(.title3.bold())
                        Text(deadline.date.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        StatusBadge(certaintyTitle, symbol: certaintySymbol, color: certaintyColor)
                        StatusBadge(status: result.status)
                    }
                }

                CoverageBar(result: result)

                HStack {
                    Text(result.margin >= 0 ? "Margine" : "Deficit")
                        .foregroundStyle(.secondary)
                    Spacer()
                    MoneyText(
                        value: result.margin,
                        style: .title3.weight(.bold),
                        color: result.margin >= 0 ? AppColor.sage : AppColor.coral
                    )
                }
            }
            .padding(18)
        }
    }

    private var certaintyTitle: String {
        deadline.certainty == .confirmed ? "Dato certo" : "Stimato"
    }

    private var certaintySymbol: String {
        deadline.certainty == .confirmed ? "checkmark.seal.fill" : "function"
    }

    private var certaintyColor: Color {
        deadline.certainty == .confirmed ? AppColor.sage : AppColor.amber
    }
}
