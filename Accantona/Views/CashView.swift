import SwiftData
import SwiftUI

struct CashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxAccountSnapshot.updatedAt, order: .reverse) private var snapshots: [TaxAccountSnapshot]
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]
    @Query(sort: \ReserveEntry.date, order: .reverse) private var reserves: [ReserveEntry]

    @State private var balanceText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenIntro(
                    title: "Cassa tasse",
                    subtitle: "Il saldo si muove con accantonamenti trasferiti e F24 registrati. Il saldo manuale serve solo a riconciliare il conto reale.",
                    symbol: "building.columns.fill",
                    tint: AppColor.petrol
                )

                balanceCard
                ledgerSummary
                pendingReservesPanel
                movementsList
                reconciliationPanel
            }
            .padding(18)
        }
        .navigationTitle("Cassa")
        .appBackground()
    }

    private var currentBalance: Decimal {
        TaxAccountLedger.balance(snapshots: snapshots, movements: movements)
    }

    private var latestSnapshot: TaxAccountSnapshot? {
        snapshots.first
    }

    private var deltaAfterReconciliation: Decimal {
        TaxAccountLedger.deltaAfterLatestSnapshot(snapshots: snapshots, movements: movements)
    }

    private var theoreticalReserve: Decimal {
        reserves.reduce(Decimal(0)) { $0 + $1.prudentialAmount }
    }

    private var actualReserve: Decimal {
        reserves.reduce(Decimal(0)) { $0 + $1.actualReservedAmount }
    }

    private var pendingReserves: [ReserveEntry] {
        reserves.filter { reserve in
            reserve.status == .pending || reserve.status == .partial || reserve.status == .skipped
        }
    }

    private var balanceCard: some View {
        GlassSurface(cornerRadius: 24, tint: AppColor.petrol) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Saldo calcolato")
                            .font(.headline)
                        Text("Base riconciliata + movimenti automatici")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge("Automatico", symbol: "arrow.triangle.2.circlepath", color: AppColor.sage)
                }

                MoneyText(value: currentBalance, style: .system(size: 42, weight: .bold, design: .rounded), color: AppColor.petrol)

                HStack {
                    Text("Ultima riconciliazione")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(latestSnapshot?.updatedAt.formatted(date: .abbreviated, time: .shortened) ?? "Mai")
                        .fontWeight(.semibold)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }

    private var ledgerSummary: some View {
        Panel(title: "Come si forma il saldo", subtitle: "La cassa non dipende piu da un numero scritto a mano.", symbol: "list.bullet.rectangle.fill", tint: AppColor.sage) {
            VStack(spacing: 0) {
                DetailRow(title: "Saldo riconciliato", value: MoneyFormatting.money(latestSnapshot?.balance ?? 0))
                DetailRow(title: "Movimenti successivi", value: MoneyFormatting.money(deltaAfterReconciliation))
                DetailRow(title: "Saldo calcolato", value: MoneyFormatting.money(currentBalance))
            }
        }
    }

    private var pendingReservesPanel: some View {
        Panel(title: "Accantonamenti da trasferire", subtitle: pendingReserves.isEmpty ? "Nessuna quota in sospeso." : "Quando trasferisci sul conto tasse, la cassa aumenta automaticamente.", symbol: "tray.and.arrow.down.fill", tint: AppColor.amber) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    DetailRow(title: "Teorico maturato", value: MoneyFormatting.money(theoreticalReserve))
                    DetailRow(title: "Gia trasferito", value: MoneyFormatting.money(actualReserve))
                    DetailRow(title: "Da recuperare", value: MoneyFormatting.money(max(theoreticalReserve - actualReserve, 0)))
                }

                if pendingReserves.isEmpty {
                    EmptyStateView(symbol: "checkmark.seal", title: "Tutto allineato", message: "Gli accantonamenti registrati risultano gia trasferiti o non ancora maturati.")
                } else {
                    ForEach(pendingReserves.prefix(5)) { reserve in
                        PendingReserveRow(reserve: reserve) {
                            markTransferred(reserve)
                        }
                    }

                    NavigationLink {
                        ReservesView()
                    } label: {
                        Label("Gestisci tutti gli accantonamenti", systemImage: "tray.full.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }

    private var movementsList: some View {
        Panel(title: "Movimenti recenti", subtitle: movements.isEmpty ? "F24 e accantonamenti trasferiti compariranno qui." : nil, symbol: "arrow.left.arrow.right", tint: AppColor.petrol) {
            if movements.isEmpty {
                EmptyStateView(symbol: "list.bullet.rectangle", title: "Nessun movimento automatico", message: "Registra un F24 o trasferisci un accantonamento per iniziare il registro.")
            } else {
                VStack(spacing: 10) {
                    ForEach(movements.prefix(8)) { movement in
                        TaxAccountMovementRow(movement: movement)
                    }
                }
            }
        }
    }

    private var reconciliationPanel: some View {
        Panel(title: "Riconcilia saldo reale", subtitle: "Usalo quando il saldo bancario non coincide con il saldo calcolato.", symbol: "slider.horizontal.below.rectangle", tint: .secondary) {
            VStack(spacing: 14) {
                AppTextField(title: "Saldo reale del conto tasse", placeholder: MoneyFormatting.money(currentBalance), text: $balanceText, keyboard: .decimalPad)
                Button {
                    reconcileBalance()
                } label: {
                    Label("Riconcilia saldo", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(balanceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseDecimal(balanceText) < 0)
            }
        }
    }

    private func markTransferred(_ reserve: ReserveEntry) {
        let isRecovery = reserve.status == .skipped || reserve.notes == "Da recuperare"
        guard let plan = ReserveAccounting.planTransfer(
            for: reserve,
            requestedAmount: ReserveAccounting.missingAmount(for: reserve),
            preservingRecovery: isRecovery
        ) else { return }
        ReserveAccounting.apply(plan, to: reserve)

        modelContext.insert(TaxAccountMovement(
            amount: plan.amount,
            kind: isRecovery ? "Recupero accantonamento" : "Accantonamento",
            note: "Quota da incasso \(MoneyFormatting.money(reserve.incomeAmount))",
            sourceId: reserve.id
        ))

        try? modelContext.save()
    }

    private func reconcileBalance() {
        let newBalance = parseDecimal(balanceText)
        modelContext.insert(TaxAccountSnapshot(balance: newBalance, updatedAt: .now))
        balanceText = ""
        try? modelContext.save()
    }

    private func parseDecimal(_ text: String) -> Decimal {
        MoneyFormatting.parseDecimal(text)
    }
}

struct PendingReserveRow: View {
    let reserve: ReserveEntry
    let onTransfer: () -> Void

    private var missingAmount: Decimal {
        max(reserve.prudentialAmount - reserve.actualReservedAmount, 0)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(reserve.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Text("Incasso \(MoneyFormatting.money(reserve.incomeAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                MoneyText(value: missingAmount, style: .headline, color: AppColor.petrol)
                Button {
                    onTransfer()
                } label: {
                    Label("Trasferito", systemImage: "arrow.down.to.line.compact")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .tint(AppColor.sage)
            }
        }
        .padding(13)
        .background(.background.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct TaxAccountMovementRow: View {
    let movement: TaxAccountMovement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: movement.amount >= 0 ? "arrow.down.to.line.compact" : "arrow.up.forward.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(movement.kind)
                    .font(.subheadline.weight(.semibold))
                Text(movement.note.isEmpty ? movement.date.formatted(date: .abbreviated, time: .omitted) : movement.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            MoneyText(value: movement.amount, style: .headline, color: color)
        }
        .padding(13)
        .background(.background.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var color: Color {
        movement.amount >= 0 ? AppColor.sage : AppColor.coral
    }
}
