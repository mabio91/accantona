import Foundation

enum TaxAccountLedger {
    static func balance(snapshots: [TaxAccountSnapshot], movements: [TaxAccountMovement]) -> Decimal {
        guard let latestSnapshot = snapshots.max(by: { $0.updatedAt < $1.updatedAt }) else {
            return movements.reduce(Decimal(0)) { $0 + $1.amount }
        }

        let delta = movements
            .filter { $0.date > latestSnapshot.updatedAt }
            .reduce(Decimal(0)) { $0 + $1.amount }

        return latestSnapshot.balance + delta
    }

    static func deltaAfterLatestSnapshot(snapshots: [TaxAccountSnapshot], movements: [TaxAccountMovement]) -> Decimal {
        guard let latestSnapshot = snapshots.max(by: { $0.updatedAt < $1.updatedAt }) else {
            return movements.reduce(Decimal(0)) { $0 + $1.amount }
        }

        return movements
            .filter { $0.date > latestSnapshot.updatedAt }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
}
