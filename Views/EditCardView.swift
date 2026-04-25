import SwiftUI
import SwiftData

struct EditCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: Item

    @State private var draftOwnerName: String
    @State private var draftStoreName: String
    @State private var draftBarcodeValue: String
    @State private var draftPointsText: String
    @State private var draftTag: String
    @State private var draftColorID: String
    @State private var ownerLimitMessage: String?
    @State private var storeLimitMessage: String?
    @State private var barcodeLimitMessage: String?
    @State private var pointsLimitMessage: String?
    @State private var previousDraftBarcodeValue: String

    init(card: Item) {
        self.card = card
        _draftOwnerName = State(initialValue: card.ownerName)
        _draftStoreName = State(initialValue: card.storeName)
        _draftBarcodeValue = State(initialValue: card.barcodeValue)
        _draftPointsText = State(initialValue: "\(card.points ?? 0)")
        _draftTag = State(initialValue: card.tag ?? "")
        _draftColorID = State(initialValue: card.colorID)
        _previousDraftBarcodeValue = State(initialValue: card.barcodeValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Modifica Card") {
                    LabeledContent("Intestatario") {
                        VStack(alignment: .trailing, spacing: 2) {
                            TextField("Nome intestatario", text: $draftOwnerName)
                                .multilineTextAlignment(.trailing)
                            if let ownerLimitMessage {
                                Text(ownerLimitMessage)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    LabeledContent("Negozio") {
                        VStack(alignment: .trailing, spacing: 2) {
                            TextField("Nome negozio", text: $draftStoreName)
                                .multilineTextAlignment(.trailing)
                            if let storeLimitMessage {
                                Text(storeLimitMessage)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    LabeledContent("Codice") {
                        VStack(alignment: .trailing, spacing: 2) {
                            TextField("Codice a barre", text: $draftBarcodeValue)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if let barcodeValidationMessage {
                                Text(barcodeValidationMessage)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    LabeledContent("Punti") {
                        VStack(alignment: .trailing, spacing: 2) {
                            TextField("0", text: $draftPointsText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                            if let pointsValidationMessage {
                                Text(pointsValidationMessage)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Section("Tag Negozio") {
                    Picker("Tag", selection: $draftTag) {
                        ForEach(CardTagCatalog.all, id: \.self) { tag in
                            Text(CardTagCatalog.displayName(for: tag)).tag(tag)
                        }
                    }
                }

                Section("Colore Card") {
                    Picker("Colore", selection: $draftColorID) {
                        ForEach(AppTheme.colorOptions) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Modifica")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard isFormValid else { return }
                        card.ownerName = draftOwnerName.trimmingCharacters(in: .whitespacesAndNewlines)
                        card.storeName = draftStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
                        card.barcodeValue = draftBarcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        card.points = parsedDraftPoints
                        card.tag = draftTag
                        card.colorID = draftColorID
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onChange(of: draftOwnerName) { _, newValue in
                CardInputValidator.enforceTextLimit(
                    text: &draftOwnerName,
                    newValue: newValue,
                    limit: CardInputLimits.ownerName,
                    message: &ownerLimitMessage
                )
            }
            .onChange(of: draftStoreName) { _, newValue in
                CardInputValidator.enforceTextLimit(
                    text: &draftStoreName,
                    newValue: newValue,
                    limit: CardInputLimits.storeName,
                    message: &storeLimitMessage
                )
            }
            .onChange(of: draftBarcodeValue) { _, newValue in
                CardInputValidator.enforceBarcodeInput(
                    text: &draftBarcodeValue,
                    newValue: newValue,
                    limit: CardInputLimits.barcode,
                    previousValue: &previousDraftBarcodeValue,
                    message: &barcodeLimitMessage
                )
            }
            .onChange(of: draftPointsText) { _, newValue in
                CardInputValidator.enforcePointsInput(
                    text: &draftPointsText,
                    newValue: newValue,
                    limit: CardInputLimits.pointsDigits,
                    message: &pointsLimitMessage
                )
            }
        }
    }

    private var isFormValid: Bool {
        ownerLimitMessage == nil &&
        storeLimitMessage == nil &&
        barcodeLimitMessage == nil &&
        !draftStoreName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draftBarcodeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        CardInputValidator.isValidCode128Input(draftBarcodeValue) &&
        pointsValidationMessage == nil
    }

    private var parsedDraftPoints: Int {
        max(0, Int(draftPointsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
    }

    private var pointsValidationMessage: String? {
        CardInputValidator.pointsValidationMessage(
            pointsText: draftPointsText,
            limitMessage: pointsLimitMessage
        )
    }

    private var barcodeValidationMessage: String? {
        CardInputValidator.barcodeValidationMessage(
            barcodeText: draftBarcodeValue,
            limitMessage: barcodeLimitMessage
        )
    }
}
