import Foundation
import SwiftData

struct PersistenceAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(_ error: Error, title: String = "Salvataggio non riuscito") {
        self.title = title
        self.message = error.localizedDescription
    }
}

enum Persistence {
    static func save(_ context: ModelContext) throws {
        try context.save()
    }
}
