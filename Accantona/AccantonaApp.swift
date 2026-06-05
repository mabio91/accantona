import SwiftData
import SwiftUI

@main
struct AccantonaApp: App {
    private let modelContainer: ModelContainer?
    private let startupError: Error?

    init() {
        do {
            try FileManager.default.createDirectory(
                at: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
                withIntermediateDirectories: true
            )
            modelContainer = try ModelContainer.accantonaContainer(inMemory: AppLaunchMode.demoScenario)
            startupError = nil
        } catch {
            modelContainer = nil
            startupError = error
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                AppView()
                    .modelContainer(modelContainer)
            } else {
                StartupFailureView(error: startupError)
            }
        }
    }
}

struct StartupFailureView: View {
    let error: Error?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppColor.coral)
            Text("Archivio non disponibile")
                .font(.headline)
            Text(error?.localizedDescription ?? "Accantona non riesce ad aprire l'archivio locale.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .appBackground()
    }
}

enum AppLaunchMode {
    static var demoScenario: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--accantona-demo-scenario")
        #else
        false
        #endif
    }
}

extension ModelContainer {
    static func accantonaContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            AppSetup.self,
            Invoice.self,
            TaxParameters.self,
            ReserveEntry.self,
            TaxAccountSnapshot.self,
            TaxAccountMovement.self,
            TaxPayment.self,
            TaxDeadline.self,
            TaxReturnSummary.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
