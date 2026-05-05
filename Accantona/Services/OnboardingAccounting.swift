import Foundation

enum OnboardingAccounting {
    static func makeInitialBalanceMovement(amount: Decimal, setup: AppSetup) -> TaxAccountMovement {
        TaxAccountMovement(
            amount: amount.roundedMoney,
            kind: "Saldo iniziale",
            note: "Saldo conto tasse configurato nel setup",
            sourceId: setup.id
        )
    }

    static func updateInitialBalanceMovement(_ movement: TaxAccountMovement, amount: Decimal, setup: AppSetup) {
        movement.amount = amount.roundedMoney
        movement.date = .now
        movement.createdAt = movement.createdAt ?? .now
        movement.note = "Saldo conto tasse configurato nel setup"
        movement.sourceId = movement.sourceId ?? setup.id
    }
}
