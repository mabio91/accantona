import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportCSVView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Invoice.issueDate, order: .reverse) private var invoices: [Invoice]
    @Query(sort: \TaxParameters.year, order: .reverse) private var parameters: [TaxParameters]

    @State private var isImporterPresented = false
    @State private var preview: InvoiceCSVImportPreview?
    @State private var importedFileName = ""
    @State private var importSummary: CSVImportSummary?
    @State private var errorMessage: String?
    @State private var persistenceAlert: PersistenceAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Importa CSV",
                    subtitle: "Carica fatture nel formato Accantona, controlla l'anteprima e salva solo le righe valide.",
                    symbol: "square.and.arrow.down.fill",
                    tint: AppColor.petrol
                )

                templatePanel
                importPanel

                if let preview {
                    previewPanel(preview)
                }

                if let importSummary {
                    summaryPanel(importSummary)
                }

                if let errorMessage {
                    Panel(title: "Errore", subtitle: errorMessage, symbol: "xmark.octagon.fill", tint: AppColor.coral) {
                        EmptyView()
                    }
                }
            }
            .padding(14)
        }
        .navigationTitle("Importa CSV")
        .appBackground()
        .alert(persistenceAlert?.title ?? "Errore", isPresented: persistenceAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlert?.message ?? "")
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
    }

    private var templatePanel: some View {
        GlassSurface(cornerRadius: 18, tint: AppColor.mint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Template fatture")
                            .font(.headline)
                        Text("Intestazione richiesta")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge("CSV standard", symbol: "doc.text.fill", color: AppColor.sage)
                }

                Text(InvoiceCSVImporter.expectedHeaders.joined(separator: ","))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.opacity(0.54), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Documentazione: docs/import-csv.md")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
    }

    private var importPanel: some View {
        Panel(
            title: importedFileName.isEmpty ? "Scegli file" : importedFileName,
            subtitle: "Date yyyy-MM-dd, importi con punto o virgola decimale.",
            symbol: "folder.fill",
            tint: AppColor.amber
        ) {
            Button {
                errorMessage = nil
                importSummary = nil
                isImporterPresented = true
            } label: {
                Label("Seleziona CSV", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
        }
    }

    private func previewPanel(_ preview: InvoiceCSVImportPreview) -> some View {
        Panel(
            title: "Anteprima",
            subtitle: "\(preview.importableRows.count) importabili, \(preview.duplicateRows.count) duplicate, \(preview.errorRows.count) errori",
            symbol: "checklist",
            tint: AppColor.petrol
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ImportStatTile(title: "Importabili", value: preview.importableRows.count, tint: AppColor.sage)
                    ImportStatTile(title: "Duplicate", value: preview.duplicateRows.count, tint: AppColor.amber)
                    ImportStatTile(title: "Errori", value: preview.errorRows.count, tint: AppColor.coral)
                }

                VStack(spacing: 10) {
                    ForEach(preview.rows.prefix(12)) { row in
                        ImportPreviewRow(row: row)
                    }
                }

                if preview.rows.count > 12 {
                    Text("Mostrate le prime 12 righe su \(preview.rows.count).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    importPreview(preview)
                } label: {
                    Label("Importa righe valide", systemImage: "square.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
                .disabled(preview.importableRows.isEmpty)
            }
        }
    }

    private func summaryPanel(_ summary: CSVImportSummary) -> some View {
        GlassSurface(cornerRadius: 18, tint: AppColor.sage) {
            VStack(alignment: .leading, spacing: 14) {
                StatusBadge("Importazione completata", symbol: "checkmark.seal.fill", color: AppColor.sage)
                HStack(spacing: 10) {
                    ImportStatTile(title: "Importate", value: summary.imported, tint: AppColor.sage)
                    ImportStatTile(title: "Saltate", value: summary.skipped, tint: AppColor.amber)
                    ImportStatTile(title: "Errori", value: summary.errors, tint: AppColor.coral)
                }
                Text("\(summary.reservesCreated) quote generate, \(summary.movementsCreated) movimenti conto tasse creati.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadCSV(from: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadCSV(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let csv = try String(contentsOf: url, encoding: .utf8)
            importedFileName = url.lastPathComponent
            preview = InvoiceCSVImporter.preview(csv: csv, existingInvoices: invoices)
        } catch {
            errorMessage = "Impossibile leggere il file: \(error.localizedDescription)"
        }
    }

    private func importPreview(_ preview: InvoiceCSVImportPreview) {
        var summary = CSVImportSummary(
            imported: 0,
            skipped: preview.duplicateRows.count,
            errors: preview.errorRows.count,
            reservesCreated: 0,
            movementsCreated: 0
        )

        let calendar = Calendar.current
        var parameterCatalog = parameters
        let createsDefaultParameters = parameterCatalog.isEmpty

        for row in preview.importableRows {
            guard let values = row.values else { continue }

            let invoice = Invoice(
                number: values.number,
                client: values.client,
                description: values.description,
                issueDate: values.issueDate,
                expectedPaymentDate: values.expectedPaymentDate,
                paidDate: values.paidDate,
                amount: values.amount,
                stampDuty: values.stampDuty,
                status: values.status,
                managementYear: calendar.component(.year, from: values.issueDate),
                fiscalYear: values.paidDate.map { calendar.component(.year, from: $0) },
                notes: values.notes
            )
            modelContext.insert(invoice)
            summary.imported += 1

            if let paidDate = values.paidDate {
                let resolution = InvoiceImportAccounting.parameter(
                    forFiscalYear: calendar.component(.year, from: paidDate),
                    parameters: parameterCatalog,
                    createsDefaultForMissingYear: createsDefaultParameters
                )
                if resolution.shouldInsert {
                    modelContext.insert(resolution.parameter)
                    parameterCatalog.append(resolution.parameter)
                }
                let parameter = resolution.parameter
                let breakdown = TaxCalculator.reserveBreakdown(for: values.amount, parameters: parameter)
                let reservedAmount = min(values.reservedAmount, breakdown.prudentialReserve).roundedMoney
                let reserve = ReserveEntry(
                    invoiceId: invoice.id,
                    date: paidDate,
                    incomeAmount: values.amount,
                    appliedRate: breakdown.appliedRate,
                    theoreticalAmount: breakdown.theoreticalReserve,
                    prudentialAmount: breakdown.prudentialReserve,
                    actualReservedAmount: reservedAmount,
                    transferDate: reservedAmount > 0 ? paidDate : nil,
                    status: reserveStatus(reservedAmount: reservedAmount, dueAmount: breakdown.prudentialReserve),
                    notes: "Generato da import CSV"
                )
                modelContext.insert(reserve)
                summary.reservesCreated += 1

                if reservedAmount > 0 {
                    modelContext.insert(TaxAccountMovement(
                        date: paidDate,
                        amount: reservedAmount,
                        kind: "Accantonamento import CSV",
                        note: "Fattura \(values.number) · \(values.client)",
                        sourceId: reserve.id
                    ))
                    summary.movementsCreated += 1
                }
            }
        }

        do {
            try Persistence.save(modelContext)
            importSummary = summary
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

    private func reserveStatus(reservedAmount: Decimal, dueAmount: Decimal) -> ReserveStatus {
        if reservedAmount <= 0 { return .pending }
        if reservedAmount >= dueAmount { return .completed }
        return .partial
    }
}

struct ImportStatTile: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ImportPreviewRow: View {
    let row: InvoiceCSVRowPreview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            StatusBadge(row.importDecision.title, symbol: symbol, color: tint)
        }
        .padding(12)
        .background(.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var title: String {
        if let values = row.values {
            return "\(values.number) · \(values.client)"
        }
        return "Riga \(row.lineNumber)"
    }

    private var subtitle: String {
        switch row.importDecision {
        case .importable, .duplicate:
            guard let values = row.values else { return "" }
            let date = values.issueDate.formatted(date: .abbreviated, time: .omitted)
            return "\(date) · \(MoneyFormatting.money(values.amount)) · \(values.status.rawValue)"
        case .invalid(let message):
            return message
        }
    }

    private var symbol: String {
        switch row.importDecision {
        case .importable: "checkmark.circle.fill"
        case .duplicate: "exclamationmark.triangle.fill"
        case .invalid: "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch row.importDecision {
        case .importable: AppColor.sage
        case .duplicate: AppColor.amber
        case .invalid: AppColor.coral
        }
    }
}

struct CSVImportSummary {
    var imported: Int
    var skipped: Int
    var errors: Int
    var reservesCreated: Int
    var movementsCreated: Int
}
