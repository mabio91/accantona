import SwiftData
import SwiftUI

@main
struct AccantonaApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .modelContainer(for: [
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
    }
}
