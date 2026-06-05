import SwiftData
import SwiftUI

struct InvoicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]
    @State private var searchText = ""
    @State private var persistenceAlert: PersistenceAlert?

    var filteredInvoices: [Invoice] {
        guard !searchText.isEmpty else { return invoices }
        return invoices.filter {
            $0.number.localizedCaseInsensitiveContains(searchText)
            || $0.client.localizedCaseInsensitiveContains(searchText)
            || $0.project.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenIntro(
                    title: "Fatture",
                    subtitle: "Incassi, quote da mettere da parte e stato pagamento restano visibili senza una lista da gestionale.",
                    symbol: "doc.text.fill",
                    tint: AppColor.petrol
                )

                if filteredInvoices.isEmpty {
                    EmptyStateView(
                        symbol: "doc.badge.plus",
                        title: "Nessuna fattura",
                        message: "Aggiungi la prima fattura per calcolare subito quota da mettere da parte e incasso residuo."
                    )
                } else {
                    VStack(spacing: 14) {
                        invoiceGroup(title: "Da incassare", symbol: "clock.fill", tint: AppColor.amber, invoices: filteredInvoices.filter { $0.status == .issued || $0.status == .draft })
                        invoiceGroup(title: "Incassate", symbol: "checkmark.circle.fill", tint: AppColor.sage, invoices: filteredInvoices.filter { $0.status == .paid })
                        invoiceGroup(title: "Archivio", symbol: "archivebox.fill", tint: .secondary, invoices: filteredInvoices.filter { $0.status == .cancelled })
                    }
                }
            }
            .padding(14)
        }
        .navigationTitle("Fatture")
        .searchable(text: $searchText, prompt: "Cliente, numero o progetto")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    InvoiceEditorView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .appBackground()
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
    }

    @ViewBuilder
    private func invoiceGroup(title: String, symbol: String, tint: Color, invoices: [Invoice]) -> some View {
        if !invoices.isEmpty {
            Panel(title: title, subtitle: "\(invoices.count) fatture", symbol: symbol, tint: tint) {
                VStack(spacing: 10) {
                    ForEach(invoices) { invoice in
                        NavigationLink {
                            InvoiceDetailView(invoice: invoice)
                        } label: {
                            InvoiceRow(invoice: invoice)
                        }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func deleteInvoices(_ sectionInvoices: [Invoice], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sectionInvoices[index])
        }
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

struct InvoiceRow: View {
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]
    let invoice: Invoice

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(invoice.number)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    StatusBadge(invoice.status.rawValue, symbol: invoice.status == .paid ? "checkmark.circle.fill" : "clock.fill", color: badgeColor)
                }
                Text(invoice.client)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let breakdown {
                    Text("Da mettere da parte \(MoneyFormatting.money(breakdown.prudentialReserve.roundedMoney))")
                        .font(.caption)
                        .foregroundStyle(AppColor.petrol)
                }
            }
            .layoutPriority(1)
            Spacer()
            MoneyText(value: invoice.amount, style: .headline)
        }
        .padding(13)
        .background(.background.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var badgeColor: Color {
        switch invoice.status {
        case .paid: AppColor.sage
        case .issued: AppColor.amber
        case .draft: .secondary
        case .cancelled: AppColor.coral
        }
    }

    private var breakdown: ReserveBreakdown? {
        guard let parameter = TaxParameterResolver.parameter(for: invoice, parameters: parameters) else { return nil }
        return TaxCalculator.reserveBreakdown(for: invoice.amount, parameters: parameter)
    }
}
