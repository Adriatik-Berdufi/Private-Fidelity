import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingCards: [Item]

    @State private var ownerName = ""
    @State private var storeName = ""
    @State private var barcodeValue = ""
    @State private var pointsText = ""
    @State private var selectedTag = ""
    @State private var selectedColorID = ""
    @State private var isShowingScanner = false
    @State private var scannerErrorMessage: String?
    @State private var isShowingDuplicateAlert = false
    @State private var ownerLimitMessage: String?
    @State private var storeLimitMessage: String?
    @State private var barcodeLimitMessage: String?
    @State private var pointsLimitMessage: String?
    @State private var previousBarcodeValue = ""

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
                        if hasDuplicateCard {
                            isShowingDuplicateAlert = true
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
            .alert("Card duplicata", isPresented: $isShowingDuplicateAlert) {
                Button("Annulla", role: .cancel) {}
                Button("Aggiungi comunque") {
                    saveCard()
                }
            } message: {
                Text("Esiste già una card con lo stesso codice a barre.")
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

    private var hasDuplicateCard: Bool {
        existingCards.contains {
            $0.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedBarcodeValue
        }
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
        let nextSortOrder = (existingCards.map(\.sortOrder).max() ?? -1) + 1

        let newCard = Item(
            ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
            storeName: normalizedStoreName,
            barcodeValue: normalizedBarcodeValue,
            tag: selectedTag,
            points: parsedPoints,
            sortOrder: nextSortOrder,
            colorID: selectedColorID
        )
        modelContext.insert(newCard)
        dismiss()
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
