import SwiftUI
import SwiftData

struct PendingCardDraft: Identifiable {
    let id = UUID()
    let ownerName: String
    let storeName: String
    let barcodeValue: String
    let points: Int
    let tag: String
    let colorID: String
}

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingCards: [Item]
    @AppStorage("defaultOwnerName") private var defaultOwnerName = ""

    @State private var ownerName = ""
    @State private var storeName = ""
    @State private var barcodeValue = ""
    @State private var pointsText = ""
    @State private var selectedTag = ""
    @State private var selectedColorID = ""
    @State private var isShowingScanner = false
    @State private var scannerErrorMessage: String?
    @State private var isShowingDuplicateAlert = false
    @State private var pendingDuplicateCard: Item?
    @State private var duplicateCardToEdit: Item?
    @State private var shouldDismissAfterDuplicateEdit = false
    @State private var ownerLimitMessage: String?
    @State private var storeLimitMessage: String?
    @State private var barcodeLimitMessage: String?
    @State private var pointsLimitMessage: String?
    @State private var previousBarcodeValue = ""
    @State private var isShowingPendingDuplicateAlert = false

    private enum SaveMode {
        case immediate
        case deferred((PendingCardDraft) -> Void)
    }

    private let blockedBarcodes: Set<String>
    private let saveMode: SaveMode

    private var isDeferredMode: Bool {
        if case .deferred = saveMode {
            return true
        }
        return false
    }

    init() {
        self.blockedBarcodes = []
        self.saveMode = .immediate
    }

    init(blockedBarcodes: Set<String>, onSaveDraft: @escaping (PendingCardDraft) -> Void) {
        self.blockedBarcodes = Set(
            blockedBarcodes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        self.saveMode = .deferred(onSaveDraft)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Button {
                            isShowingScanner = true
                        } label: {
                            Label("Scansiona con fotocamera", systemImage: "barcode.viewfinder")
                                .font(.headline)
                                .fontDesign(.rounded)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.16, green: 0.52, blue: 0.50), Color(red: 0.10, green: 0.37, blue: 0.45)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)

                        Group {
                            StyledTextField(
                                title: "Nome intestatario",
                                text: $ownerName,
                                icon: "person.fill",
                                helperMessage: ownerLimitMessage
                            )
                            StyledTextField(
                                title: "Nome negozio",
                                text: $storeName,
                                icon: "bag.fill",
                                helperMessage: storeLimitMessage
                            )
                            StyledTextField(
                                title: "Codice a barre",
                                text: $barcodeValue,
                                icon: "barcode",
                                monospaced: true,
                                helperMessage: barcodeValidationMessage
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            StyledTextField(
                                title: "Punti",
                                text: $pointsText,
                                icon: "star.fill",
                                helperMessage: pointsValidationMessage
                            )
                            .keyboardType(.numberPad)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tipo Negozio")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("Tipo negozio", selection: $selectedTag) {
                                ForEach(CardTagCatalog.all, id: \.self) { tag in
                                    Text(CardTagCatalog.displayName(for: tag)).tag(tag)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Colore Card")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("Colore card", selection: $selectedColorID) {
                                ForEach(AppTheme.colorOptions) { option in
                                    Text(option.name).tag(option.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Nuova Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard isFormValid else { return }
                        if let duplicateCard = duplicateCard {
                            if isDeferredMode {
                                pendingDuplicateCard = nil
                                isShowingPendingDuplicateAlert = true
                            } else {
                                pendingDuplicateCard = duplicateCard
                                isShowingDuplicateAlert = true
                            }
                        } else if hasPendingDuplicate {
                            isShowingPendingDuplicateAlert = true
                        } else {
                            saveCard()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Errore fotocamera", isPresented: scannerAlertIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerErrorMessage ?? "")
            }
            .alert("Card già presente", isPresented: $isShowingDuplicateAlert) {
                Button("No", role: .cancel) {
                    pendingDuplicateCard = nil
                    shouldDismissAfterDuplicateEdit = false
                }
                Button("Sì") {
                    duplicateCardToEdit = pendingDuplicateCard
                    pendingDuplicateCard = nil
                    shouldDismissAfterDuplicateEdit = true
                }
            } message: {
                Text("Questo codice QR è già presente. Vuoi modificare quella card?")
            }
            .alert("Card già presente", isPresented: $isShowingPendingDuplicateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if isDeferredMode {
                    Text("In Impostazioni non puoi salvare o modificare subito una card duplicata. Usa la penna in Modifica card e poi premi Salva in Impostazioni.")
                } else {
                    Text("Questo codice QR è già stato aggiunto nelle modifiche in attesa di Salva.")
                }
            }
            .sheet(item: $duplicateCardToEdit, onDismiss: {
                if shouldDismissAfterDuplicateEdit {
                    shouldDismissAfterDuplicateEdit = false
                    dismiss()
                }
            }) { card in
                EditCardView(card: card)
            }
            .sheet(isPresented: $isShowingScanner) {
                NavigationStack {
                    BarcodeScannerView { scannedCode in
                        barcodeValue = scannedCode
                        isShowingScanner = false
                    } onFailure: { message in
                        scannerErrorMessage = message
                        isShowingScanner = false
                    }
                    .ignoresSafeArea()
                    .navigationTitle("Scanner")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Chiudi") {
                                isShowingScanner = false
                            }
                        }
                    }
                }
            }
            .onChange(of: ownerName) { _, newValue in
                CardInputValidator.enforceTextLimit(
                    text: &ownerName,
                    newValue: newValue,
                    limit: CardInputLimits.ownerName,
                    message: &ownerLimitMessage
                )
            }
            .onChange(of: storeName) { _, newValue in
                CardInputValidator.enforceTextLimit(
                    text: &storeName,
                    newValue: newValue,
                    limit: CardInputLimits.storeName,
                    message: &storeLimitMessage
                )
            }
            .onChange(of: barcodeValue) { _, newValue in
                CardInputValidator.enforceBarcodeInput(
                    text: &barcodeValue,
                    newValue: newValue,
                    limit: CardInputLimits.barcode,
                    previousValue: &previousBarcodeValue,
                    message: &barcodeLimitMessage
                )
            }
            .onChange(of: pointsText) { _, newValue in
                CardInputValidator.enforcePointsInput(
                    text: &pointsText,
                    newValue: newValue,
                    limit: CardInputLimits.pointsDigits,
                    message: &pointsLimitMessage
                )
            }
            .onAppear {
                previousBarcodeValue = barcodeValue
                if ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ownerName = String(defaultOwnerName.prefix(CardInputLimits.ownerName))
                }
            }
        }
    }

    private var isFormValid: Bool {
        ownerLimitMessage == nil &&
        storeLimitMessage == nil &&
        barcodeLimitMessage == nil &&
        !normalizedStoreName.isEmpty &&
        !normalizedBarcodeValue.isEmpty &&
        CardInputValidator.isValidCode128Input(normalizedBarcodeValue) &&
        pointsValidationMessage == nil
    }

    private var duplicateCard: Item? {
        existingCards.first {
            $0.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedBarcodeValue
        }
    }

    private var hasPendingDuplicate: Bool {
        guard duplicateCard == nil else {
            return false
        }
        return blockedBarcodes.contains(normalizedBarcodeValue)
    }

    private var normalizedStoreName: String {
        storeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedBarcodeValue: String {
        barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var scannerAlertIsPresented: Binding<Bool> {
        Binding(
            get: { scannerErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    scannerErrorMessage = nil
                }
            }
        )
    }

    private func saveCard() {
        let draft = PendingCardDraft(
            ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
            storeName: normalizedStoreName,
            barcodeValue: normalizedBarcodeValue,
            points: parsedPoints,
            tag: selectedTag,
            colorID: selectedColorID
        )

        switch saveMode {
        case .deferred(let onSaveDraft):
            onSaveDraft(draft)
            dismiss()
        case .immediate:
            let nextSortOrder = (existingCards.map(\.sortOrder).max() ?? -1) + 1
            let newCard = Item(
                ownerName: draft.ownerName,
                storeName: draft.storeName,
                barcodeValue: draft.barcodeValue,
                tag: draft.tag,
                points: draft.points,
                sortOrder: nextSortOrder,
                colorID: draft.colorID
            )
            modelContext.insert(newCard)
            dismiss()
        }
    }

    private var parsedPoints: Int {
        max(0, Int(pointsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
    }

    private var barcodeValidationMessage: String? {
        CardInputValidator.barcodeValidationMessage(
            barcodeText: normalizedBarcodeValue,
            limitMessage: barcodeLimitMessage
        )
    }

    private var pointsValidationMessage: String? {
        CardInputValidator.pointsValidationMessage(
            pointsText: pointsText,
            limitMessage: pointsLimitMessage
        )
    }
}
