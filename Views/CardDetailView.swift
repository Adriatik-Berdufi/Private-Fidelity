import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCards: [Item]

    let card: Item
    @State private var isShowingDeleteAlert = false
    @State private var isShowingEditSheet = false
    @State private var shareSheetItem: ShareSheetItem?
    @State private var shareErrorMessage: String?
    @State private var isShowingAdjustPointsAlert = false
    @State private var pointsInputText = ""
    @State private var pointsAdjustmentMode: PointsAdjustmentMode = .add

    var body: some View {
        let tint = AppTheme.tint(for: card)

        ScrollView {
            VStack(spacing: 120) {
                VStack(spacing: 8) {
                    VStack(spacing: 8) {
                        if let barcodeImage = BarcodeGenerator.makeCode128(from: card.barcodeValue) {
                            VStack(spacing: 0) {
                                Text(card.storeName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.black.opacity(0.65))

                                Image(uiImage: barcodeImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 240)

                                Text(card.barcodeValue)
                                    .font(.system(size: 13, design: .monospaced))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.black.opacity(0.75))
                                    .padding(.top, -14)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            Text("Impossibile generare il barcode")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Punti accumulati")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("\(currentPoints)")
                                .font(.title.weight(.bold))
                                .fontDesign(.rounded)
                                .foregroundStyle(.primary)
                        }
                        Spacer()

                        HStack(spacing: 10) {
                            Button {
                                pointsInputText = ""
                                pointsAdjustmentMode = .subtract
                                isShowingAdjustPointsAlert = true
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.orange)

                            Button {
                                pointsInputText = ""
                                pointsAdjustmentMode = .add
                                isShowingAdjustPointsAlert = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(card.storeName.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.9))

                        Spacer()

                        Button {
                            toggleFavorite()
                        } label: {
                            Image(systemName: card.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(card.ownerName)
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)

                    if let tag = card.tag, !tag.isEmpty {
                        Text(CardTagCatalog.displayName(for: tag))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .shadow(color: tint.opacity(0.25), radius: 18, x: 0, y: 10)
            }
            .padding()
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Dettaglio Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }

                Button {
                    prepareCardShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    isShowingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("Eliminare questa card?", isPresented: $isShowingDeleteAlert) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                modelContext.delete(card)
                dismiss()
            }
        } message: {
            Text("L'operazione non puo essere annullata.")
        }
        .sheet(isPresented: $isShowingEditSheet) {
            EditCardView(card: card)
        }
        .sheet(item: $shareSheetItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert(pointsAdjustmentMode.alertTitle, isPresented: $isShowingAdjustPointsAlert) {
            TextField(pointsAdjustmentMode.textFieldTitle, text: $pointsInputText)
                .keyboardType(.numberPad)
            Button("Annulla", role: .cancel) {}
            Button(pointsAdjustmentMode.confirmButtonTitle) {
                adjustPoints()
            }
            .disabled(parsedPointsInput == nil)
        } message: {
            Text(pointsAdjustmentMode.message)
        }
        .alert("Errore condivisione", isPresented: shareErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    private func toggleFavorite() {
        if card.isFavorite {
            card.isFavorite = false
            card.favoriteOrder = 0
        } else {
            let nextFavoriteOrder = (allCards.filter(\.isFavorite).map(\.favoriteOrder).max() ?? -1) + 1
            card.isFavorite = true
            card.favoriteOrder = nextFavoriteOrder
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Errore salvataggio preferiti: \(error.localizedDescription)")
        }
    }

    private var currentPoints: Int {
        card.points ?? 0
    }

    private var parsedPointsInput: Int? {
        guard let value = Int(pointsInputText.trimmingCharacters(in: .whitespacesAndNewlines)),
              value > 0 else {
            return nil
        }
        return value
    }

    private func adjustPoints() {
        guard let input = parsedPointsInput else {
            return
        }

        switch pointsAdjustmentMode {
        case .add:
            card.points = currentPoints + input
        case .subtract:
            card.points = max(0, currentPoints - input)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Errore salvataggio punti: \(error.localizedDescription)")
        }
    }

    private enum PointsAdjustmentMode {
        case add
        case subtract

        var alertTitle: String {
            switch self {
            case .add:
                return "Aggiungi punti"
            case .subtract:
                return "Rimuovi punti"
            }
        }

        var textFieldTitle: String {
            switch self {
            case .add:
                return "Punti da aggiungere"
            case .subtract:
                return "Punti da rimuovere"
            }
        }

        var confirmButtonTitle: String {
            switch self {
            case .add:
                return "Aggiungi"
            case .subtract:
                return "Rimuovi"
            }
        }

        var message: String {
            switch self {
            case .add:
                return "Inserisci quanti punti vuoi aggiungere."
            case .subtract:
                return "Inserisci quanti punti vuoi rimuovere."
            }
        }
    }

    private var shareErrorIsPresented: Binding<Bool> {
        Binding(
            get: { shareErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    shareErrorMessage = nil
                }
            }
        )
    }

    private func prepareCardShare() {
        do {
            let payload = CardTransferPayload(
                ownerName: card.ownerName,
                storeName: card.storeName,
                barcodeValue: card.barcodeValue,
                tag: card.tag ?? "",
                colorID: card.colorID,
                isFavorite: card.isFavorite
            )
            let fileURL = try CardTransferCodec.encodeToTemporaryFile(payload)
            shareSheetItem = ShareSheetItem(url: fileURL)
        } catch {
            shareErrorMessage = "Impossibile preparare la condivisione: \(error.localizedDescription)"
        }
    }
}
