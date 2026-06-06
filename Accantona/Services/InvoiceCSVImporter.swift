import Foundation

struct InvoiceCSVImportPreview {
    let rows: [InvoiceCSVRowPreview]

    var importableRows: [InvoiceCSVRowPreview] {
        rows.filter { $0.importDecision == .importable }
    }

    var duplicateRows: [InvoiceCSVRowPreview] {
        rows.filter { $0.importDecision == .duplicate }
    }

    var errorRows: [InvoiceCSVRowPreview] {
        rows.filter {
            if case .invalid = $0.importDecision { return true }
            return false
        }
    }
}

struct InvoiceCSVRowPreview: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let values: ImportedInvoiceValues?
    let importDecision: InvoiceCSVImportDecision
}

struct ImportedInvoiceValues {
    let number: String
    let client: String
    let description: String
    let issueDate: Date
    let expectedPaymentDate: Date?
    let paidDate: Date?
    let amount: Decimal
    let stampDuty: Decimal
    let status: InvoiceStatus
    let notes: String
    let reservedAmount: Decimal
}

enum InvoiceCSVImportDecision: Equatable {
    case importable
    case duplicate
    case invalid(String)

    var title: String {
        switch self {
        case .importable: "Importabile"
        case .duplicate: "Duplicata"
        case .invalid: "Errore"
        }
    }
}

struct InvoiceDuplicateKey: Hashable {
    let number: String
    let client: String
    let issueDate: Date

    init(number: String, client: String, issueDate: Date) {
        self.number = number.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.client = client.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.issueDate = Calendar.current.startOfDay(for: issueDate)
    }

    init(invoice: Invoice) {
        self.init(number: invoice.number, client: invoice.client, issueDate: invoice.issueDate)
    }
}

enum InvoiceCSVImporter {
    static let expectedHeaders = [
        "numero",
        "cliente",
        "descrizione",
        "data_emissione",
        "data_incasso_prevista",
        "data_incasso",
        "importo",
        "bollo",
        "stato",
        "note",
        "importo_accantonato"
    ]

    static let template = """
    numero,cliente,descrizione,data_emissione,data_incasso_prevista,data_incasso,importo,bollo,stato,note,importo_accantonato
    1/2026,Cliente Alpha,Consulenza strategica,2026-01-15,2026-02-15,,3333.34,2,emessa,Da incassare,
    2/2026,Cliente Beta,Workshop,2026-02-01,2026-02-20,2026-02-18,1800,2,incassata,Incassata senza accantonamento,
    3/2026,Cliente Gamma,Retainer,2026-03-01,2026-03-30,2026-03-28,2500,2,incassata,Accantonamento parziale,500
    """

    @MainActor
    static func preview(csv: String, existingInvoices: [Invoice]) -> InvoiceCSVImportPreview {
        let delimiter = detectDelimiter(in: csv)
        let parsedRows = parseRows(csv, delimiter: delimiter)
        guard let header = parsedRows.first else {
            return InvoiceCSVImportPreview(rows: [
                InvoiceCSVRowPreview(lineNumber: 1, values: nil, importDecision: .invalid("File vuoto"))
            ])
        }

        guard normalizedHeaders(header) == expectedHeaders else {
            return InvoiceCSVImportPreview(rows: [
                InvoiceCSVRowPreview(lineNumber: 1, values: nil, importDecision: .invalid("Intestazione CSV non valida"))
            ])
        }

        var seenKeys = Set(existingInvoices.map(InvoiceDuplicateKey.init(invoice:)))
        var previews: [InvoiceCSVRowPreview] = []

        for (offset, columns) in parsedRows.dropFirst().enumerated() {
            let lineNumber = offset + 2
            guard !columns.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                continue
            }

            let normalizedColumns = normalizeColumnCount(columns, delimiter: delimiter)
            guard normalizedColumns.count == expectedHeaders.count else {
                previews.append(InvoiceCSVRowPreview(
                    lineNumber: lineNumber,
                    values: nil,
                    importDecision: .invalid("Colonne attese: \(expectedHeaders.count), trovate: \(columns.count)")
                ))
                continue
            }

            do {
                let values = try values(from: normalizedColumns)
                let key = InvoiceDuplicateKey(number: values.number, client: values.client, issueDate: values.issueDate)
                if seenKeys.contains(key) {
                    previews.append(InvoiceCSVRowPreview(lineNumber: lineNumber, values: values, importDecision: .duplicate))
                } else {
                    seenKeys.insert(key)
                    previews.append(InvoiceCSVRowPreview(lineNumber: lineNumber, values: values, importDecision: .importable))
                }
            } catch {
                previews.append(InvoiceCSVRowPreview(
                    lineNumber: lineNumber,
                    values: nil,
                    importDecision: .invalid(error.localizedDescription)
                ))
            }
        }

        return InvoiceCSVImportPreview(rows: previews)
    }

    private static func values(from columns: [String]) throws -> ImportedInvoiceValues {
        let number = clean(columns[0])
        let client = clean(columns[1])
        guard !number.isEmpty else { throw ImportError("Numero fattura mancante") }
        guard !client.isEmpty else { throw ImportError("Cliente mancante") }

        let issueDate = try parseRequiredDate(columns[3], field: "data_emissione")
        let expectedPaymentDate = try parseOptionalDate(columns[4], field: "data_incasso_prevista")
        let paidDate = try parseOptionalDate(columns[5], field: "data_incasso")
        let amount = try parseRequiredDecimal(columns[6], field: "importo")
        let stampDuty = try parseOptionalDecimal(columns[7], field: "bollo")
        let parsedStatus = try parseStatus(columns[8], paidDate: paidDate)
        let status = paidDate == nil ? parsedStatus : .paid
        let reservedAmount = try parseOptionalDecimal(columns[10], field: "importo_accantonato")

        guard amount > 0 else { throw ImportError("Importo deve essere maggiore di zero") }
        if reservedAmount < 0 { throw ImportError("Importo accantonato non può essere negativo") }
        if status == .paid, paidDate == nil { throw ImportError("Una fattura incassata deve avere data_incasso") }

        return ImportedInvoiceValues(
            number: number,
            client: client,
            description: clean(columns[2]),
            issueDate: issueDate,
            expectedPaymentDate: expectedPaymentDate,
            paidDate: paidDate,
            amount: amount.roundedMoney,
            stampDuty: stampDuty.roundedMoney,
            status: status,
            notes: clean(columns[9]),
            reservedAmount: reservedAmount.roundedMoney
        )
    }

    private static func detectDelimiter(in csv: String) -> Character {
        guard let firstLine = csv.split(whereSeparator: \.isNewline).first else { return "," }
        return firstLine.contains(";") ? ";" : ","
    }

    private static func parseRows(_ csv: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var iterator = csv.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isInsideQuotes {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            isInsideQuotes = false
                            if next == delimiter {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else if next != "\r" {
                                field.append(next)
                            }
                        }
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    isInsideQuotes = true
                }
            } else if character == delimiter, !isInsideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !isInsideQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    private static func normalizeColumnCount(_ columns: [String], delimiter: Character) -> [String] {
        guard delimiter == ",", columns.count == expectedHeaders.count + 1 else { return columns }
        var normalized = columns
        normalized[6] = normalized[6] + "," + normalized[7]
        normalized.remove(at: 7)
        return normalized
    }

    private static func normalizedHeaders(_ headers: [String]) -> [String] {
        headers.map { clean($0).lowercased() }
    }

    private static func parseStatus(_ value: String, paidDate: Date?) throws -> InvoiceStatus {
        let normalized = clean(value).lowercased()
        if normalized.isEmpty, paidDate != nil { return .paid }
        if normalized.isEmpty { return .issued }

        switch normalized {
        case "bozza": return .draft
        case "emessa": return .issued
        case "incassata": return .paid
        case "annullata": return .cancelled
        default: throw ImportError("Stato non ammesso: \(value)")
        }
    }

    private static func parseRequiredDate(_ value: String, field: String) throws -> Date {
        guard let date = parseDate(value) else { throw ImportError("\(field) non valida, usa yyyy-MM-dd") }
        return date
    }

    private static func parseOptionalDate(_ value: String, field: String) throws -> Date? {
        let trimmed = clean(value)
        guard !trimmed.isEmpty else { return nil }
        guard let date = parseDate(trimmed) else { throw ImportError("\(field) non valida, usa yyyy-MM-dd") }
        return date
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: clean(value))
    }

    private static func parseRequiredDecimal(_ value: String, field: String) throws -> Decimal {
        guard let decimal = parseDecimal(value) else { throw ImportError("\(field) non valido") }
        return decimal
    }

    private static func parseOptionalDecimal(_ value: String, field: String) throws -> Decimal {
        let trimmed = clean(value)
        guard !trimmed.isEmpty else { return 0 }
        guard let decimal = parseDecimal(trimmed) else { throw ImportError("\(field) non valido") }
        return decimal
    }

    static func parseDecimal(_ value: String) -> Decimal? {
        let compact = clean(value)
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
        let normalized: String
        if compact.contains(",") {
            normalized = compact
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = compact
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ImportError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
