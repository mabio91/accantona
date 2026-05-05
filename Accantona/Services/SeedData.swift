import Foundation
import SwiftData

enum SeedData {
    static func installIfNeeded(context: ModelContext) {
        let setupDescriptor = FetchDescriptor<AppSetup>()
        let setups = (try? context.fetch(setupDescriptor)) ?? []
        guard setups.isEmpty else { return }

        let hasParameters = !(((try? context.fetch(FetchDescriptor<TaxParameters>())) ?? []).isEmpty)
        let hasDeadlines = !(((try? context.fetch(FetchDescriptor<TaxDeadline>())) ?? []).isEmpty)
        let hasMovements = !(((try? context.fetch(FetchDescriptor<TaxAccountMovement>())) ?? []).isEmpty)
        let hasSnapshots = !(((try? context.fetch(FetchDescriptor<TaxAccountSnapshot>())) ?? []).isEmpty)
        let hasInvoices = !(((try? context.fetch(FetchDescriptor<Invoice>())) ?? []).isEmpty)
        let hasExistingData = hasParameters || hasDeadlines || hasMovements || hasSnapshots || hasInvoices

        context.insert(AppSetup(
            onboardingCompleted: hasExistingData,
            completedAt: hasExistingData ? .now : nil
        ))

        try? context.save()
    }
}
