import Foundation

enum CardInputLimits {
    static let ownerName = 40
    static let storeName = 20
    static let barcode = 128
    static let pointsDigits = 10
    static let colorID = 16
    static let tag = 20
}

enum CardInputValidator {
    static func enforceTextLimit(
        text: inout String,
        newValue: String,
        limit: Int,
        message: inout String?
    ) {
        let limited = String(newValue.prefix(limit))
        if limited != newValue {
            text = limited
            message = "Hai superato il massimo di \(limit) caratteri."
            return
        }

        if limited.count < limit {
            message = nil
        }
    }

    static func enforcePointsInput(
        text: inout String,
        newValue: String,
        limit: Int,
        message: inout String?
    ) {
        let digitsOnly = newValue.filter(\.isNumber)
        let limited = String(digitsOnly.prefix(limit))
        if limited != newValue {
            text = limited
            message = digitsOnly.count > limit
                ? "Hai superato il massimo di \(limit) caratteri."
                : "Sono consentiti solo numeri."
            return
        }

        if limited.count < limit {
            message = nil
        }
    }

    static func enforceBarcodeInput(
        text: inout String,
        newValue: String,
        limit: Int,
        previousValue: inout String,
        message: inout String?
    ) {
        let oldValue = previousValue
        let oldTrimmed = oldValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldWasInvalid = !oldTrimmed.isEmpty && !isValidCode128Input(oldTrimmed)

        if oldWasInvalid && newValue.count > oldValue.count {
            text = oldValue
            message = "Barcode non valido: correggilo prima di aggiungere altri caratteri."
            return
        }

        let limited = String(newValue.prefix(limit))
        if limited != newValue {
            text = limited
            previousValue = limited
            message = "Hai superato il massimo di \(limit) caratteri."
            return
        }

        previousValue = limited
        if limited.count < limit {
            message = nil
        }
    }

    static func pointsValidationMessage(
        pointsText: String,
        limitMessage: String?,
        digitsLimit: Int = CardInputLimits.pointsDigits
    ) -> String? {
        if let limitMessage {
            return limitMessage
        }

        let normalized = pointsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return nil
        }

        guard normalized.allSatisfy(\.isNumber) else {
            return "Punti non validi: inserisci solo numeri."
        }

        if normalized.count > digitsLimit {
            return "Punti: massimo \(digitsLimit) cifre."
        }

        return nil
    }

    static func barcodeValidationMessage(
        barcodeText: String,
        limitMessage: String?
    ) -> String? {
        if let limitMessage {
            return limitMessage
        }

        let normalized = barcodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return nil
        }

        return isValidCode128Input(normalized)
            ? nil
            : "Barcode non valido: usa caratteri standard (ASCII)."
    }

    static func normalizedTag(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func customTagValidationMessage(
        tagText: String,
        limitMessage: String?,
        existingTags: [String]
    ) -> String? {
        if let limitMessage {
            return limitMessage
        }

        let normalized = normalizedTag(tagText)
        if normalized.isEmpty {
            return nil
        }

        let exists = existingTags.contains {
            normalizedTag($0).caseInsensitiveCompare(normalized) == .orderedSame
        }
        return exists ? "Tag già presente." : nil
    }

    static func isValidCode128Input(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return trimmed.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && scalar.value >= 32 && scalar.value <= 126
        }
    }
}
