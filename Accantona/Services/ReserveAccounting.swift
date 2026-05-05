import Foundation

struct ReserveTransferPlan {
    let amount: Decimal
    let resultingReservedAmount: Decimal
    let resultingStatus: ReserveStatus
}

enum ReserveAccounting {
    static func missingAmount(for reserve: ReserveEntry) -> Decimal {
        max(reserve.prudentialAmount - reserve.actualReservedAmount, 0).roundedMoney
    }

    static func planTransfer(for reserve: ReserveEntry, requestedAmount: Decimal, preservingRecovery: Bool = false) -> ReserveTransferPlan? {
        let amount = min(max(requestedAmount, 0), missingAmount(for: reserve)).roundedMoney
        guard amount > 0 else { return nil }

        let resultingReservedAmount = (reserve.actualReservedAmount + amount).roundedMoney
        let isComplete = resultingReservedAmount >= reserve.prudentialAmount.roundedMoney
        let status: ReserveStatus
        if isComplete {
            status = preservingRecovery ? .recovered : .completed
        } else {
            status = preservingRecovery ? .skipped : .partial
        }

        return ReserveTransferPlan(
            amount: amount,
            resultingReservedAmount: resultingReservedAmount,
            resultingStatus: status
        )
    }

    static func apply(_ plan: ReserveTransferPlan, to reserve: ReserveEntry, transferDate: Date = .now) {
        reserve.actualReservedAmount = plan.resultingReservedAmount
        reserve.transferDate = transferDate
        reserve.status = plan.resultingStatus
    }
}
