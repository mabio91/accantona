import SwiftData
import SwiftUI

enum ReserveFilter: String, CaseIterable, Identifiable {
    case all = "Tutti"
    case pending = "Da trasferire"
    case partial = "Parziali"
    case completed = "Sul conto tasse"
    case recovery = "Da recuperare"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: "tray.full.fill"
        case .pending: "clock.fill"
        case .partial: "circle.lefthalf.filled"
        case .completed: "checkmark.seal.fill"
        case .recovery: "arrow.counterclockwise.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: AppColor.petrol
        case .pending: AppColor.amber
        case .partial: AppColor.petrol
        case .completed: AppColor.sage
        case .recovery: AppColor.coral
        }
    }

    func includes(_ reserve: ReserveEntry) -> Bool {
        switch self {
        case .all:
            true
        case .pending:
            reserve.status == .pending
        case .partial:
            reserve.status == .partial
        case .completed:
            reserve.status == .completed || reserve.status == .recovered
        case .recovery:
            reserve.status == .skipped
        }
    }
}

struct ReservesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReserveEntry.date, order: .reverse) private var reserves: [ReserveEntry]
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]

    @State private var selectedFilter: ReserveFilter = .all
    @State private var partialReserve: ReserveEntry?
    @State private var partialAmountText = ""
    @State private var persistenceAlert: PersistenceAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Accantonamenti",
                    subtitle: "Ogni incasso genera una quota da trasferire sul conto tasse. Qui vedi cosa manca e cosa e gia stato spostato.",
                    symbol: "tray.and.arrow.down.fill",
                    tint: AppColor.petrol
                )

                totalsHeader
                filterBar
                reservesPanel
            }
            .padding(14)
        }
        .navigationTitle("Accantonamenti")
        .appBackground()
        .sheet(item: $partialReserve) { reserve in
            partialReserveSheet(reserve)
                .presentationDetents([.medium])
        }
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
    }

    private var filteredReserves: [ReserveEntry] {
        reserves.filter { selectedFilter.includes($0) }
    }

    private var totalToRecover: Decimal {
        reserves
            .filter { $0.status == .pending || $0.status == .partial || $0.status == .skipped }
            .reduce(Decimal(0)) { $0 + missingAmount(for: $1) }
    }

    private var totalReserved: Decimal {
        reserves.reduce(Decimal(0)) { $0 + $1.actualReservedAmount }
    }

    private var totalsHeader: some View {
        GlassSurface(cornerRadius: 18, tint: AppColor.mint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Quote fiscali dagli incassi")
                            .font(.headline)
                        Text("Da trasferire o gia sul conto tasse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge("Conto tasse", symbol: "arrow.triangle.2.circlepath", color: AppColor.sage)
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ancora da trasferire")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        MoneyText(value: totalToRecover, style: .system(size: 26, weight: .bold, design: .rounded), color: totalToRecover > 0 ? AppColor.coral : AppColor.sage)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Gia sul conto tasse")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        MoneyText(value: totalReserved, style: .title3.weight(.bold), color: AppColor.petrol)
                    }
                }
            }
            .padding(14)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ReserveFilter.allCases) { filter in
                    Button {
                        withAnimation(.snappy) {
                            selectedFilter = filter
                        }
                    } label: {
                        Label(filter.rawValue, systemImage: filter.symbol)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(filterBackground(filter), in: Capsule())
                            .foregroundStyle(filter == selectedFilter ? .white : filter.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func filterBackground(_ filter: ReserveFilter) -> Color {
        filter == selectedFilter ? filter.tint : filter.tint.opacity(0.13)
    }

    private var reservesPanel: some View {
        Panel(
            title: selectedFilter.rawValue,
            subtitle: filteredReserves.isEmpty ? "Nessuna quota in questo stato." : "\(filteredReserves.count) quote",
            symbol: selectedFilter.symbol,
            tint: selectedFilter.tint
        ) {
            if filteredReserves.isEmpty {
                EmptyStateView(
                    symbol: "checkmark.seal",
                    title: "Niente da mostrare",
                    message: "Cambia filtro o registra un incasso per generare un accantonamento."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredReserves) { reserve in
                        ReserveCard(
                            reserve: reserve,
                            invoice: invoice(for: reserve),
                            missingAmount: missingAmount(for: reserve),
                            onReserveAll: { reserveAll(reserve) },
                            onReservePartial: {
                                partialAmountText = ""
                                partialReserve = reserve
                            },
                            onMarkRecovery: { markAsRecovery(reserve) }
                        )
                    }
                }
            }
        }
    }

    private func partialReserveSheet(_ reserve: ReserveEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.secondary.opacity(0.28))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)

            Text("Trasferisci una parte")
                .font(.title3.bold())

            ReserveAmountSummary(
                incomeAmount: reserve.incomeAmount,
                dueAmount: reserve.prudentialAmount,
                reservedAmount: reserve.actualReservedAmount,
                missingAmount: missingAmount(for: reserve)
            )

            AppTextField(
                title: "Importo trasferito",
                placeholder: MoneyFormatting.money(missingAmount(for: reserve).roundedMoney),
                text: $partialAmountText,
                keyboard: .decimalPad
            )

            Button {
                reservePartial(reserve, amount: parseDecimal(partialAmountText))
                partialReserve = nil
            } label: {
                Label("Registra trasferimento", systemImage: "tray.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
            .disabled(parseDecimal(partialAmountText) <= 0)
        }
        .padding(16)
        .appBackground()
    }

    private func invoice(for reserve: ReserveEntry) -> Invoice? {
        guard let invoiceId = reserve.invoiceId else { return nil }
        return invoices.first { $0.id == invoiceId }
    }

    private func missingAmount(for reserve: ReserveEntry) -> Decimal {
        ReserveAccounting.missingAmount(for: reserve)
    }

    private func reserveAll(_ reserve: ReserveEntry) {
        reservePartial(reserve, amount: missingAmount(for: reserve))
    }

    private func reservePartial(_ reserve: ReserveEntry, amount: Decimal) {
        let wasRecovery = reserve.status == .skipped || reserve.notes == "Da recuperare"
        guard let plan = ReserveAccounting.planTransfer(for: reserve, requestedAmount: amount, preservingRecovery: wasRecovery) else { return }

        ReserveAccounting.apply(plan, to: reserve)
        if wasRecovery, reserve.notes.isEmpty {
            reserve.notes = "Da recuperare"
        }

        let invoiceLabel = invoice(for: reserve).map { "Fattura \($0.number) · \($0.client)" }
        modelContext.insert(TaxAccountMovement(
            amount: plan.amount,
            kind: wasRecovery ? "Recupero accantonamento" : "Accantonamento",
            note: invoiceLabel ?? "Quota da incasso \(MoneyFormatting.money(reserve.incomeAmount))",
            sourceId: reserve.id
        ))
        saveChanges()
    }

    private func markAsRecovery(_ reserve: ReserveEntry) {
        guard reserve.status != .completed && reserve.status != .recovered else { return }
        reserve.status = .skipped
        reserve.notes = reserve.notes.isEmpty ? "Da recuperare" : reserve.notes
        saveChanges()
    }

    private func parseDecimal(_ text: String) -> Decimal {
        MoneyFormatting.parseDecimal(text)
    }

    private func saveChanges() {
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

struct ReserveCard: View {
    let reserve: ReserveEntry
    let invoice: Invoice?
    let missingAmount: Decimal
    let onReserveAll: () -> Void
    let onReservePartial: () -> Void
    let onMarkRecovery: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(statusColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text(invoiceTitle)
                        .font(.headline)
                    Text(reserve.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                StatusBadge(statusTitle, symbol: statusSymbol, color: statusColor)
            }

            ReserveAmountSummary(
                incomeAmount: reserve.incomeAmount,
                dueAmount: reserve.prudentialAmount,
                reservedAmount: reserve.actualReservedAmount,
                missingAmount: missingAmount
            )

            if canAct {
                HStack(spacing: 10) {
                    Button {
                        onReserveAll()
                    } label: {
                        Label("Tutto", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .primaryActionStyle()
                    .disabled(missingAmount <= 0)

                    Button {
                        onReservePartial()
                    } label: {
                        Label("Parte", systemImage: "circle.lefthalf.filled")
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .secondaryActionStyle()
                    .disabled(missingAmount <= 0)

                    Button {
                        onMarkRecovery()
                    } label: {
                        Label("Recupera", systemImage: "arrow.counterclockwise")
                            .labelStyle(.iconOnly)
                    }
                    .secondaryActionStyle()
                    .tint(AppColor.coral)
                    .disabled(reserve.status == .skipped)
                    .accessibilityLabel("Segna come da recuperare")
                }
                .controlSize(.regular)
            }
        }
        .padding(14)
        .background(.background.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var invoiceTitle: String {
        if let invoice {
            "Fattura \(invoice.number) · \(invoice.client)"
        } else {
            "Incasso non collegato"
        }
    }

    private var statusTitle: String {
        switch reserve.status {
        case .pending: "Da trasferire"
        case .partial: "Trasferito in parte"
        case .completed: "Sul conto tasse"
        case .skipped: "Da recuperare"
        case .recovered: "Recuperato"
        }
    }

    private var statusSymbol: String {
        switch reserve.status {
        case .pending: "clock.fill"
        case .partial: "circle.lefthalf.filled"
        case .completed: "checkmark.seal.fill"
        case .skipped: "arrow.counterclockwise.circle.fill"
        case .recovered: "checkmark.seal.fill"
        }
    }

    private var statusColor: Color {
        switch reserve.status {
        case .pending: AppColor.amber
        case .partial: AppColor.petrol
        case .completed: AppColor.sage
        case .skipped: AppColor.coral
        case .recovered: AppColor.sage
        }
    }

    private var canAct: Bool {
        reserve.status != .completed && reserve.status != .recovered
    }
}

struct ReserveAmountSummary: View {
    let incomeAmount: Decimal
    let dueAmount: Decimal
    let reservedAmount: Decimal
    let missingAmount: Decimal

    var body: some View {
        VStack(spacing: 0) {
            DetailRow(title: "Incasso collegato", value: MoneyFormatting.money(incomeAmount))
            DetailRow(title: "Da mettere da parte", value: MoneyFormatting.money(dueAmount))
            DetailRow(title: "Gia trasferito", value: MoneyFormatting.money(reservedAmount))
            DetailRow(title: "Ancora da trasferire", value: MoneyFormatting.money(missingAmount))
        }
        .background(.regularMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
