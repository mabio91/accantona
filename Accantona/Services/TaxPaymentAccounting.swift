import Foundation

enum TaxPaymentAccounting {
    struct Validation {
        let title: String
        let message: String
        let isBlocking: Bool
    }

    static func coveredAmount(for payment: TaxPayment) -> Decimal {
        payment.coveredAmount.roundedMoney
    }

    static func ledgerAmount(for payment: TaxPayment) -> Decimal {
        (-payment.amountPaid).roundedMoney
    }

    static func ledgerKind(for payment: TaxPayment) -> String {
        payment.amountPaid < 0 ? "F24 credito \(payment.type.rawValue)" : "F24 \(payment.type.rawValue)"
    }

    static func ledgerNote(for payment: TaxPayment) -> String {
        let code = payment.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let codeText = code.isEmpty ? payment.section.rawValue : "\(payment.section.rawValue) · \(code)"
        let creditText = payment.amountCompensated > 0 ? " · credito \(MoneyFormatting.money(payment.amountCompensated))" : ""
        return codeText + creditText
    }

    static func makeLedgerMovement(for payment: TaxPayment) -> TaxAccountMovement {
        TaxAccountMovement(
            date: payment.paymentDate,
            amount: ledgerAmount(for: payment),
            kind: ledgerKind(for: payment),
            note: ledgerNote(for: payment),
            sourceId: payment.id
        )
    }

    static func updateLedgerMovement(_ movement: TaxAccountMovement, for payment: TaxPayment) {
        movement.date = payment.paymentDate
        movement.createdAt = movement.createdAt ?? .now
        movement.amount = ledgerAmount(for: payment)
        movement.kind = ledgerKind(for: payment)
        movement.note = ledgerNote(for: payment)
        movement.sourceId = payment.id
    }

    static func validation(
        type: TaxPaymentType,
        section: TaxPaymentSection,
        code rawCode: String,
        amountDebt: Decimal,
        amountCompensated: Decimal,
        amountPaid: Decimal
    ) -> Validation? {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if amountDebt < 0 || amountCompensated < 0 {
            return Validation(title: "Importi non validi", message: "Debito e credito compensato non possono essere negativi.", isBlocking: true)
        }

        if amountDebt == 0, amountCompensated == 0, amountPaid == 0 {
            return Validation(title: "Importi mancanti", message: "Inserisci almeno un debito, un credito compensato o un netto pagato.", isBlocking: true)
        }

        if amountDebt > 0, amountCompensated > amountDebt {
            return Validation(title: "Credito maggiore del debito", message: "Il credito compensato supera il debito indicato. Usa un netto negativo solo se stai registrando un credito F24.", isBlocking: false)
        }

        switch code {
        case "1790":
            if section != .erario || type != .balance {
                return Validation(title: "Codice 1790", message: "Di solito 1790 indica il saldo imposta sostitutiva in sezione Erario.", isBlocking: false)
            }
        case "1791":
            if section != .erario || type != .firstAdvance {
                return Validation(title: "Codice 1791", message: "Di solito 1791 indica il primo acconto imposta sostitutiva in sezione Erario.", isBlocking: false)
            }
        case "1792":
            if section != .erario || type != .secondAdvance {
                return Validation(title: "Codice 1792", message: "Di solito 1792 indica il secondo acconto, oppure un credito nello stesso contesto.", isBlocking: false)
            }
        case "7005":
            if section != .inps {
                return Validation(title: "Causale 7005/PXX", message: "Le causali INPS Gestione Separata vanno normalmente in sezione INPS.", isBlocking: false)
            }
        default:
            if code.hasPrefix("P"), section != .inps {
                return Validation(title: "Causale INPS", message: "Le causali PXX sono normalmente contributi INPS Gestione Separata.", isBlocking: false)
            }
        }

        return nil
    }
}
