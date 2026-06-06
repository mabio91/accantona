import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var setups: [AppSetup]
    @Query private var invoices: [Invoice]
    @Query private var taxParameters: [TaxParameters]
    @Query private var reserves: [ReserveEntry]
    @Query private var snapshots: [TaxAccountSnapshot]
    @Query private var movements: [TaxAccountMovement]
    @Query private var taxPayments: [TaxPayment]
    @Query private var deadlines: [TaxDeadline]
    @Query private var taxReturns: [TaxReturnSummary]

    @State private var exportDocument = BackupFileDocument()
    @State private var exportFilename = AppBackupService.defaultFilename()
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingRestoreData: Data?
    @State private var pendingRestoreSummary: AppBackupSummary?
    @State private var showRestoreAlert = false
    @State private var showDeleteFirstAlert = false
    @State private var showDeleteFinalAlert = false
    @State private var activeAlert: DataManagementAlert?

    private var summary: AppBackupSummary {
        AppBackupSummary(
            setups: setups.count,
            invoices: invoices.count,
            taxParameters: taxParameters.count,
            reserves: reserves.count,
            snapshots: snapshots.count,
            movements: movements.count,
            taxPayments: taxPayments.count,
            deadlines: deadlines.count,
            taxReturns: taxReturns.count
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenIntro(
                    title: "Backup e dati",
                    subtitle: "Esporta un archivio locale, ripristina un backup Accantona o azzera l'app.",
                    symbol: "externaldrive.fill",
                    tint: AppColor.petrol
                )

                Panel(title: "Archivio corrente", subtitle: "\(summary.totalRecords) record salvati sul dispositivo.", symbol: "tray.full.fill", tint: AppColor.sage) {
                    DataSummaryGrid(summary: summary)
                }

                Panel(title: "Backup", subtitle: "Il file JSON contiene setup, fatture, accantonamenti, movimenti, F24, scadenze e dichiarazioni.", symbol: "arrow.up.doc.fill", tint: AppColor.petrol) {
                    VStack(spacing: 12) {
                        Button(action: exportBackup) {
                            Label("Crea backup", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .primaryActionStyle()
                        .disabled(summary.totalRecords == 0)

                        Button(action: { isImporting = true }) {
                            Label("Ripristina backup", systemImage: "arrow.down.doc.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryActionStyle()
                    }
                }

                Panel(title: "Area pericolosa", subtitle: "La cancellazione elimina l'archivio locale e riapre il setup iniziale.", symbol: "exclamationmark.triangle.fill", tint: AppColor.coral) {
                    Button(role: .destructive) {
                        showDeleteFirstAlert = true
                    } label: {
                        Label("Elimina tutti i dati", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryActionStyle()
                    .tint(AppColor.coral)
                    .disabled(summary.totalRecords == 0)
                }
            }
            .padding(14)
        }
        .navigationTitle("Backup e dati")
        .appBackground()
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename,
            onCompletion: handleExportCompletion
        )
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportCompletion
        )
        .alert(
            activeAlert?.title ?? "Accantona",
            isPresented: activeAlertBinding,
            presenting: activeAlert,
            actions: alertActions,
            message: alertMessage
        )
        .alert("Ripristinare backup?", isPresented: $showRestoreAlert) {
            Button("Annulla", role: .cancel) {
                pendingRestoreData = nil
                pendingRestoreSummary = nil
            }
            Button("Ripristina", role: .destructive, action: restorePendingBackup)
        } message: {
            Text("Il backup contiene \(pendingRestoreSummary?.totalRecords ?? 0) record. I dati attuali verranno sostituiti.")
        }
        .alert("Eliminare tutti i dati?", isPresented: $showDeleteFirstAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Continua", role: .destructive) {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    showDeleteFinalAlert = true
                }
            }
        } message: {
            Text("Questa azione rimuove setup, fatture, accantonamenti, movimenti, F24, scadenze e dichiarazioni.")
        }
        .alert("Ultima conferma", isPresented: $showDeleteFinalAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina definitivamente", role: .destructive, action: deleteAllData)
        } message: {
            Text("Operazione irreversibile. Conferma solo se hai già creato un backup o sei sicuro di voler azzerare l'app.")
        }
    }

    private func exportBackup() {
        do {
            exportDocument = BackupFileDocument(data: try AppBackupService.encodedBackup(context: modelContext))
            exportFilename = AppBackupService.defaultFilename()
            isExporting = true
        } catch {
            activeAlert = .error(title: "Backup non riuscito", message: error.localizedDescription)
        }
    }

    private func handleExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            activeAlert = .notice(title: "Backup creato", message: "Il file contiene \(summary.totalRecords) record dell'archivio Accantona.")
        case .failure(let error):
            activeAlert = .error(title: "Backup non salvato", message: error.localizedDescription)
        }
    }

    private func handleImportCompletion(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                activeAlert = .error(title: "File mancante", message: "Seleziona un file di backup Accantona.")
                return
            }
            importBackup(from: url)
        case .failure(let error):
            activeAlert = .error(title: "Backup non letto", message: error.localizedDescription)
        }
    }

    private func importBackup(from url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let importSummary = try AppBackupService.preview(from: data)
            pendingRestoreData = data
            pendingRestoreSummary = importSummary
            showRestoreAlert = true
        } catch {
            activeAlert = .error(title: "Backup non valido", message: error.localizedDescription)
        }
    }

    private func restorePendingBackup() {
        guard let data = pendingRestoreData else { return }
        do {
            let restored = try AppBackupService.restoreBackup(from: data, into: modelContext)
            pendingRestoreData = nil
            pendingRestoreSummary = nil
            activeAlert = .notice(title: "Backup ripristinato", message: "\(restored.totalRecords) record ripristinati correttamente.")
        } catch {
            activeAlert = .error(title: "Ripristino non riuscito", message: error.localizedDescription)
        }
    }

    private func deleteAllData() {
        do {
            let deleted = try AppBackupService.deleteAllData(in: modelContext)
            activeAlert = .notice(title: "Dati eliminati", message: "\(deleted.totalRecords) record rimossi. Il setup iniziale si aprirà automaticamente.")
        } catch {
            activeAlert = .error(title: "Cancellazione non riuscita", message: error.localizedDescription)
        }
    }

    @ViewBuilder
    private func alertActions(_ alert: DataManagementAlert) -> some View {
        switch alert {
        case .notice, .error:
            Button("OK", role: .cancel) { }
        }
    }

    @ViewBuilder
    private func alertMessage(_ alert: DataManagementAlert) -> some View {
        Text(alert.message)
    }

    private var activeAlertBinding: Binding<Bool> {
        Binding(
            get: { activeAlert != nil },
            set: { isPresented in
                if !isPresented {
                    activeAlert = nil
                }
            }
        )
    }
}

private struct DataSummaryGrid: View {
    let summary: AppBackupSummary

    private var rows: [(String, Int, String)] {
        [
            ("Setup", summary.setups, "sparkles.rectangle.stack.fill"),
            ("Fatture", summary.invoices, "doc.text.fill"),
            ("Parametri", summary.taxParameters, "slider.horizontal.3"),
            ("Accantonamenti", summary.reserves, "tray.and.arrow.down.fill"),
            ("Movimenti", summary.movements, "building.columns.fill"),
            ("F24", summary.taxPayments, "doc.plaintext.fill"),
            ("Scadenze", summary.deadlines, "calendar.badge.clock"),
            ("Dichiarazioni", summary.taxReturns, "doc.text.magnifyingglass")
        ]
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(rows, id: \.0) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.2)
                        .font(.caption.weight(.semibold))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(AppColor.petrol)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.0)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(row.1)")
                            .font(.headline.monospacedDigit())
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private enum DataManagementAlert {
    case notice(title: String, message: String)
    case error(title: String, message: String)

    var title: String {
        switch self {
        case .notice(let title, _), .error(let title, _):
            title
        }
    }

    var message: String {
        switch self {
        case .notice(_, let message), .error(_, let message):
            message
        }
    }
}

private struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw AppBackupError.missingFileContents
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
