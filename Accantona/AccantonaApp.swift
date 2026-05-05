import SwiftData
import SwiftUI

@main
struct AccantonaApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer.accantonaContainer(inMemory: AppLaunchMode.demoScenario)
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .modelContainer(modelContainer)
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
