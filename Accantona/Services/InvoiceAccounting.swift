import Foundation

enum InvoiceAccounting {
    static func paidDate(for status: InvoiceStatus, selectedPaidDate: Date) -> Date? {
        status == .paid ? selectedPaidDate : nil
    }

    static func fiscalYear(for paidDate: Date?) -> Int? {
        paidDate.map { Calendar.current.component(.year, from: $0) }
    }
}
