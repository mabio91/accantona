import SwiftData
import SwiftUI

struct CashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaxAccountSnapshot.updatedAt, order: .reverse) private var snapshots: [TaxAccountSnapshot]
    @Query(sort: \TaxAccountMovement.date, order: .reverse) private var movements: [TaxAccountMovement]
    @Query(sort: \ReserveEntry.date, order: .reverse) private var reserves: [ReserveEntry]

    @State private var balanceText = ""
    @State private var persistenceAlert: PersistenceAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Cassa tasse",
                    subtitle: "Mostra il denaro sul conto tasse: aumenta con le quote trasferite dagli incassi e diminuisce con gli F24.",
                    symbol: "building.columns.fill",
                    tint: AppColor.petrol
                )

                balanceCard
                ledgerSummary
                pendingReservesPanel
                movementsList
                reconciliationPanel
            }
            .padding(14)
        }
        .navigationTitle("Cassa")
        .appBackground()
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
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
        GlassSurface(cornerRadius: 18, tint: AppColor.petrol) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Saldo conto tasse calcolato")
                            .font(.headline)
                        Text("Ultima riconciliazione + trasferimenti - F24")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge("Automatico", symbol: "arrow.triangle.2.circlepath", color: AppColor.sage)
                }

                MoneyText(value: currentBalance, style: .system(size: 30, weight: .bold, design: .rounded), color: AppColor.petrol)

                HStack {
                    Text("Ultima riconciliazione manuale")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(latestSnapshot?.updatedAt.formatted(date: .abbreviated, time: .shortened) ?? "Mai")
                        .fontWeight(.semibold)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    private var ledgerSummary: some View {
        Panel(title: "Come si forma il saldo conto tasse", subtitle: "Il saldo calcolato parte dall'ultima riconciliazione e somma solo i movimenti successivi.", symbol: "list.bullet.rectangle.fill", tint: AppColor.sage) {
            VStack(spacing: 0) {
                DetailRow(title: "Saldo dell'ultima riconciliazione", value: MoneyFormatting.money(latestSnapshot?.balance ?? 0))
                DetailRow(title: "Movimenti dopo la riconciliazione", value: MoneyFormatting.money(deltaAfterReconciliation))
                DetailRow(title: "Saldo conto tasse calcolato", value: MoneyFormatting.money(currentBalance))
            }
        }
    }

    private var pendingReservesPanel: some View {
        Panel(title: "Quote da trasferire sul conto tasse", subtitle: pendingReserves.isEmpty ? "Nessuna quota in sospeso." : "Quando registri il trasferimento, il saldo conto tasse aumenta.", symbol: "tray.and.arrow.down.fill", tint: AppColor.amber) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    DetailRow(title: "Quote maturate dagli incassi", value: MoneyFormatting.money(theoreticalReserve))
                    DetailRow(title: "Già trasferito sul conto tasse", value: MoneyFormatting.money(actualReserve))
                    DetailRow(title: "Ancora da trasferire", value: MoneyFormatting.money(max(theoreticalReserve - actualReserve, 0)))
                }

                if pendingReserves.isEmpty {
                    EmptyStateView(symbol: "checkmark.seal", title: "Tutto allineato", message: "Le quote maturate risultano già trasferite oppure non ci sono incassi da accantonare.")
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
                    .secondaryActionStyle()
                }
            }
        }
    }

    private var movementsList: some View {
        Panel(title: "Movimenti recenti", subtitle: movements.isEmpty ? "Trasferimenti sul conto tasse e F24 compariranno qui." : nil, symbol: "arrow.left.arrow.right", tint: AppColor.petrol) {
            if movements.isEmpty {
                EmptyStateView(symbol: "list.bullet.rectangle", title: "Nessun movimento", message: "Registra un F24 o trasferisci una quota sul conto tasse per iniziare il registro.")
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
        Panel(title: "Allinea al saldo reale", subtitle: "Usalo quando il saldo reale del conto tasse non coincide con quello calcolato dall'app.", symbol: "slider.horizontal.below.rectangle", tint: .secondary) {
            VStack(spacing: 14) {
                AppTextField(title: "Saldo reale sul conto tasse", placeholder: MoneyFormatting.money(currentBalance), text: $balanceText, keyboard: .decimalPad)
                Button {
                    reconcileBalance()
                } label: {
                    Label("Allinea saldo", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionStyle()
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

        saveChanges()
    }

    private func reconcileBalance() {
        let newBalance = parseDecimal(balanceText)
        modelContext.insert(TaxAccountSnapshot(balance: newBalance, updatedAt: .now))
        balanceText = ""
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
                .secondaryActionStyle()
                .tint(AppColor.sage)
                .accessibilityLabel("Segna quota come trasferita sul conto tasse")
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
