//
//  ContentView.swift
//  private-fidelity
//
//  Created by Adriatik Berdufi on 18/04/2026.
//

import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Item.sortOrder), SortDescriptor(\Item.createdAt, order: .reverse)]) private var cards: [Item]

    @State private var isPresentingAddCard = false
    @State private var isPresentingImportPicker = false
    @State private var isPresentingExportPicker = false
    @State private var isPresentingSettings = false
    @State private var draggedCard: Item?
    @State private var selectedCard: Item?
    @State private var importAlertMessage: String?
    @State private var exportAlertMessage: String?
    @State private var shareSheetItem: ShareSheetItem?
    @State private var allCardsFilter: AllCardsFilter = .all
    @State private var searchText = ""

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                if cards.isEmpty {
                    EmptyStateView {
                        isPresentingAddCard = true
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            sectionTitle("Preferiti")

                            LazyVGrid(columns: gridColumns, spacing: 12) {
                                ForEach(filteredPreferredCards) { card in
                                    cardTile(card, context: .favorites)
                                }
                            }

                            sectionTitle("Tutte le card")

                            Picker("Filtro card", selection: $allCardsFilter) {
                                ForEach(AllCardsFilter.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)

                            if allCardsFilter == .all {
                                LazyVGrid(columns: gridColumns, spacing: 12) {
                                    ForEach(filteredAllCards) { card in
                                        cardTile(card, context: .all)
                                    }
                                }
                            } else {
                                ForEach(allCardsGroupedByTag) { group in
                                    sectionTitle(CardTagCatalog.displayName(for: group.tag))

                                    LazyVGrid(columns: gridColumns, spacing: 12) {
                                        ForEach(group.cards) { card in
                                            cardTile(card, context: .all)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                        .padding(.bottom, 16)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Button {
                            isPresentingAddCard = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }

                        Menu {
                            Button("Impostazioni", systemImage: "gearshape") {
                                isPresentingSettings = true
                            }

                            Button("Aggiungi", systemImage: "plus.circle") {
                                isPresentingAddCard = true
                            }

                            Button("Importa", systemImage: "square.and.arrow.down") {
                                isPresentingImportPicker = true
                            }

                            Button("Esporta", systemImage: "square.and.arrow.up") {
                                isPresentingExportPicker = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddCard) {
                AddCardView()
            }
            .sheet(isPresented: $isPresentingExportPicker) {
                ExportCardsView(cards: cards) { selectedCards in
                    exportCards(selectedCards)
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView()
            }
            .fileImporter(
                isPresented: $isPresentingImportPicker,
                allowedContentTypes: [CardTransferCodec.fileType, .json],
                allowsMultipleSelection: false
            ) { result in
                importCard(from: result)
            }
            .sheet(item: $shareSheetItem) { item in
                ActivityView(activityItems: [item.url])
            }
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card)
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Cerca negozio"
            )
            .alert("Importazione", isPresented: importAlertIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importAlertMessage ?? "")
            }
            .alert("Esportazione", isPresented: exportAlertIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportAlertMessage ?? "")
            }
        }
    }

    private var preferredCards: [Item] {
        cards
            .filter { $0.isFavorite }
            .sorted { lhs, rhs in
                if lhs.favoriteOrder == rhs.favoriteOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.favoriteOrder < rhs.favoriteOrder
            }
    }

    private var allCards: [Item] {
        cards.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredPreferredCards: [Item] {
        guard !normalizedSearchText.isEmpty else {
            return preferredCards
        }
        return preferredCards.filter {
            $0.storeName.lowercased().contains(normalizedSearchText)
        }
    }

    private var filteredAllCards: [Item] {
        guard !normalizedSearchText.isEmpty else {
            return allCards
        }
        return allCards.filter {
            $0.storeName.lowercased().contains(normalizedSearchText)
        }
    }

    private var allCardsGroupedByTag: [TagGroup] {
        let grouped = Dictionary(grouping: filteredAllCards) { card in
            normalizedTag(card.tag)
        }

        var groups: [TagGroup] = []
        for tag in CardTagCatalog.all where grouped[tag] != nil {
            groups.append(TagGroup(tag: tag, cards: grouped[tag] ?? []))
        }

        let knownTags = Set(CardTagCatalog.all)
        let unknownTags = grouped.keys
            .filter { !knownTags.contains($0) }
            .sorted()
        for tag in unknownTags {
            groups.append(TagGroup(tag: tag, cards: grouped[tag] ?? []))
        }

        return groups
    }

    private func normalizedTag(_ tag: String?) -> String {
        (tag ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private enum CardListContext {
        case favorites
        case all
    }

    private enum AllCardsFilter: String, CaseIterable, Identifiable {
        case all
        case byTag

        var id: Self { self }

        var title: String {
            switch self {
            case .all:
                return "Tutte"
            case .byTag:
                return "Per Tag"
            }
        }
    }

    private struct TagGroup: Identifiable {
        let tag: String
        let cards: [Item]

        var id: String {
            tag.isEmpty ? "__no_tag__" : tag
        }
    }

    @ViewBuilder
    private func cardTile(_ card: Item, context: CardListContext) -> some View {
        switch context {
        case .favorites:
            baseCardTile(card)
                .onDrop(
                    of: [UTType.text],
                    delegate: CardDropDelegate(
                        targetCard: card,
                        cards: preferredCards,
                        draggedCard: $draggedCard,
                        onMove: moveFavoriteCard
                    )
                )
        case .all:
            baseCardTile(card)
                .onDrop(
                    of: [UTType.text],
                    delegate: CardDropDelegate(
                        targetCard: card,
                        cards: allCards,
                        draggedCard: $draggedCard,
                        onMove: moveCard
                    )
                )
        }
    }

    private func baseCardTile(_ card: Item) -> some View {
        CardRowView(card: card)
            .onTapGesture {
                selectedCard = card
            }
            .onDrag {
                draggedCard = card
                return NSItemProvider(object: NSString(string: card.barcodeValue))
            }
    }

    private var importAlertIsPresented: Binding<Bool> {
        Binding(
            get: { importAlertMessage != nil },
            set: { newValue in
                if !newValue {
                    importAlertMessage = nil
                }
            }
        )
    }

    private var exportAlertIsPresented: Binding<Bool> {
        Binding(
            get: { exportAlertMessage != nil },
            set: { newValue in
                if !newValue {
                    exportAlertMessage = nil
                }
            }
        )
    }

    private func importCard(from result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else {
                importAlertMessage = "Nessun file selezionato."
                return
            }

            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let fileData = try Data(contentsOf: url)
            let transferredCards = try CardTransferCodec.decodeCards(fileData)
            var nextSortOrder = (cards.map(\.sortOrder).max() ?? -1) + 1
            var nextFavoriteOrder = (cards.filter(\.isFavorite).map(\.favoriteOrder).max() ?? -1) + 1

            for transferredCard in transferredCards {
                let item = Item(
                    ownerName: transferredCard.ownerName,
                    storeName: transferredCard.storeName,
                    barcodeValue: transferredCard.barcodeValue,
                    tag: transferredCard.tag,
                    sortOrder: nextSortOrder,
                    favoriteOrder: transferredCard.isFavorite ? nextFavoriteOrder : 0,
                    isFavorite: transferredCard.isFavorite,
                    colorID: transferredCard.colorID
                )
                modelContext.insert(item)
                nextSortOrder += 1
                if transferredCard.isFavorite {
                    nextFavoriteOrder += 1
                }
            }

            try modelContext.save()
            importAlertMessage = transferredCards.count == 1
                ? "Card importata con successo."
                : "\(transferredCards.count) card importate con successo."
        } catch {
            importAlertMessage = "Importazione fallita: \(error.localizedDescription)"
        }
    }

    private func exportCards(_ selectedCards: [Item]) {
        guard !selectedCards.isEmpty else {
            exportAlertMessage = "Seleziona almeno una card da esportare."
            return
        }

        do {
            let payloads = selectedCards.map {
                CardTransferPayload(
                    ownerName: $0.ownerName,
                    storeName: $0.storeName,
                    barcodeValue: $0.barcodeValue,
                    tag: $0.tag ?? "",
                    colorID: $0.colorID,
                    isFavorite: $0.isFavorite
                )
            }
            let fileURL = try CardTransferCodec.encodeCardsToTemporaryFile(payloads)
            shareSheetItem = ShareSheetItem(url: fileURL)
        } catch {
            exportAlertMessage = "Esportazione fallita: \(error.localizedDescription)"
        }
    }

    private func moveCard(_ dragged: Item, before target: Item) {
        guard dragged.persistentModelID != target.persistentModelID else {
            return
        }

        var reorderedCards = allCards

        guard
            let fromIndex = reorderedCards.firstIndex(where: { $0.persistentModelID == dragged.persistentModelID }),
            let toIndex = reorderedCards.firstIndex(where: { $0.persistentModelID == target.persistentModelID })
        else {
            return
        }

        reorderedCards.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)

        for (index, card) in reorderedCards.enumerated() {
            card.sortOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Errore salvataggio ordinamento tutte le card: \(error.localizedDescription)")
        }
    }

    private func moveFavoriteCard(_ dragged: Item, before target: Item) {
        guard dragged.persistentModelID != target.persistentModelID else {
            return
        }

        var reorderedFavorites = preferredCards

        guard
            let fromIndex = reorderedFavorites.firstIndex(where: { $0.persistentModelID == dragged.persistentModelID }),
            let toIndex = reorderedFavorites.firstIndex(where: { $0.persistentModelID == target.persistentModelID })
        else {
            return
        }

        reorderedFavorites.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)

        for (index, card) in reorderedFavorites.enumerated() {
            card.favoriteOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Errore salvataggio ordinamento preferiti: \(error.localizedDescription)")
        }
    }
}

private struct ExportCardsView: View {
    @Environment(\.dismiss) private var dismiss

    let cards: [Item]
    let onExport: ([Item]) -> Void
    @State private var selectedIDs: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if cards.isEmpty {
                    ContentUnavailableView("Nessuna card", systemImage: "tray")
                        .frame(maxHeight: .infinity)
                } else {
                    List(cards, id: \.persistentModelID) { card in
                        Button {
                            toggleSelection(for: card.persistentModelID)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selectedIDs.contains(card.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(card.persistentModelID) ? Color.accentColor : Color.secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.storeName)
                                        .foregroundStyle(.primary)
                                    Text(card.barcodeValue)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)

                    VStack(spacing: 10) {
                        Button("Esporta (\(selectedCards.count))") {
                            onExport(selectedCards)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedCards.isEmpty)
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
            }
            .navigationTitle("Esporta Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selectedIDs.count == cards.count ? "Deseleziona" : "Seleziona tutte") {
                        if selectedIDs.count == cards.count {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(cards.map(\.persistentModelID))
                        }
                    }
                    .disabled(cards.isEmpty)
                }
            }
        }
    }

    private var selectedCards: [Item] {
        cards.filter { selectedIDs.contains($0.persistentModelID) }
    }

    private func toggleSelection(for id: PersistentIdentifier) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

private struct CardDropDelegate: DropDelegate {
    let targetCard: Item
    let cards: [Item]
    @Binding var draggedCard: Item?
    let onMove: (Item, Item) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedCard else {
            return
        }

        guard draggedCard.persistentModelID != targetCard.persistentModelID else {
            return
        }

        let draggedExists = cards.contains { $0.persistentModelID == draggedCard.persistentModelID }
        let targetExists = cards.contains { $0.persistentModelID == targetCard.persistentModelID }

        guard draggedExists, targetExists else {
            return
        }

        onMove(draggedCard, targetCard)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let draggedCard, draggedCard.persistentModelID != targetCard.persistentModelID {
            onMove(draggedCard, targetCard)
        }
        self.draggedCard = nil
        return true
    }
}

private struct CardRowView: View {
    let card: Item

    private var ownerInitials: String {
        let parts = card.ownerName
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(2)

        let initials = parts.compactMap { $0.first?.uppercased() }.joined(separator: "")
        return initials.isEmpty ? "--" : initials
    }

    var body: some View {
        let tint = AppTheme.tint(for: card)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: CardTagCatalog.iconName(for: card.tag))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.2), in: Circle())

                Text(card.storeName)
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ownerInitials)
                    .font(.caption.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Text(card.barcodeValue)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [tint, tint.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.28), radius: 14, x: 0, y: 8)
    }
}

struct ShareSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CardTransferPayload: Codable {
    let ownerName: String
    let storeName: String
    let barcodeValue: String
    let tag: String
    let colorID: String
    let isFavorite: Bool

    private enum CodingKeys: String, CodingKey {
        case ownerName
        case storeName
        case barcodeValue
        case tag
        case colorID
        case isFavorite
    }

    init(ownerName: String, storeName: String, barcodeValue: String, tag: String = "", colorID: String, isFavorite: Bool) {
        self.ownerName = ownerName
        self.storeName = storeName
        self.barcodeValue = barcodeValue
        self.tag = tag
        self.colorID = colorID
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ownerName = try container.decode(String.self, forKey: .ownerName)
        storeName = try container.decode(String.self, forKey: .storeName)
        barcodeValue = try container.decode(String.self, forKey: .barcodeValue)
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
        colorID = try container.decode(String.self, forKey: .colorID)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
    }
}

struct CardTransferBundle: Codable {
    let version: Int
    let cards: [CardTransferPayload]
}

struct LegacySingleCardPayload: Codable {
    let version: Int
    let ownerName: String
    let storeName: String
    let barcodeValue: String
    let colorID: String
    let isFavorite: Bool
}

enum CardTransferCodec {
    static let fileType = UTType(filenameExtension: "private-fidelitycard") ?? .json
    private static let supportedVersion = 1
    private static let maxFileSizeBytes = 250 * 1024
    private static let maxCardsPerFile = 100
    private static let maxOwnerNameLength = CardInputLimits.ownerName
    private static let maxStoreNameLength = CardInputLimits.storeName
    private static let maxBarcodeLength = CardInputLimits.barcode
    private static let maxColorIDLength = CardInputLimits.colorID
    private static let maxTagLength = CardInputLimits.tag

    static func encodeToTemporaryFile(_ payload: CardTransferPayload) throws -> URL {
        try encodeCardsToTemporaryFile([payload])
    }

    static func encodeCardsToTemporaryFile(_ payloads: [CardTransferPayload]) throws -> URL {
        guard !payloads.isEmpty else {
            throw CardTransferError.emptyBundle
        }

        let bundle = CardTransferBundle(version: 1, cards: payloads)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)

        let fileName: String
        if payloads.count == 1, let first = payloads.first {
            let cleanStoreName = first.storeName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "-")
            let fallbackStoreName = cleanStoreName.isEmpty ? "card" : cleanStoreName
            fileName = "\(fallbackStoreName)-\(first.barcodeValue)"
        } else {
            fileName = "private-fidelity-cards-\(payloads.count)"
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("private-fidelitycard")

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    static func decodeCards(_ data: Data) throws -> [CardTransferPayload] {
        guard !data.isEmpty else {
            throw CardTransferError.emptyFile
        }
        guard data.count <= maxFileSizeBytes else {
            throw CardTransferError.fileTooLarge
        }

        let decoder = JSONDecoder()
        if let bundle = try? decoder.decode(CardTransferBundle.self, from: data) {
            guard bundle.version == supportedVersion else {
                throw CardTransferError.unsupportedVersion
            }
            guard !bundle.cards.isEmpty else {
                throw CardTransferError.emptyBundle
            }
            guard bundle.cards.count <= maxCardsPerFile else {
                throw CardTransferError.tooManyCards
            }
            try validate(bundle.cards)
            return bundle.cards
        }

        let legacySinglePayload = try decoder.decode(LegacySingleCardPayload.self, from: data)
        guard legacySinglePayload.version == supportedVersion else {
            throw CardTransferError.unsupportedVersion
        }
        let singlePayload = CardTransferPayload(
            ownerName: legacySinglePayload.ownerName,
            storeName: legacySinglePayload.storeName,
            barcodeValue: legacySinglePayload.barcodeValue,
            colorID: legacySinglePayload.colorID,
            isFavorite: legacySinglePayload.isFavorite
        )
        try validate([singlePayload])
        return [singlePayload]
    }

    private static func validate(_ payloads: [CardTransferPayload]) throws {
        var seenKeys = Set<String>()

        for payload in payloads {
            let ownerName = payload.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
            let storeName = payload.storeName.trimmingCharacters(in: .whitespacesAndNewlines)
            let barcodeValue = payload.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let colorID = payload.colorID.trimmingCharacters(in: .whitespacesAndNewlines)
            let tag = payload.tag.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !storeName.isEmpty else {
                throw CardTransferError.invalidStoreName
            }
            guard !barcodeValue.isEmpty else {
                throw CardTransferError.invalidBarcode
            }
            guard ownerName.count <= maxOwnerNameLength else {
                throw CardTransferError.ownerNameTooLong
            }
            guard storeName.count <= maxStoreNameLength else {
                throw CardTransferError.storeNameTooLong
            }
            guard barcodeValue.count <= maxBarcodeLength else {
                throw CardTransferError.barcodeTooLong
            }
            guard colorID.count <= maxColorIDLength else {
                throw CardTransferError.colorIDTooLong
            }
            guard tag.count <= maxTagLength else {
                throw CardTransferError.tagTooLong
            }
            guard !containsControlCharacters(ownerName),
                  !containsControlCharacters(storeName),
                  !containsControlCharacters(barcodeValue),
                  !containsControlCharacters(colorID),
                  !containsControlCharacters(tag) else {
                throw CardTransferError.invalidCharacters
            }

            let dedupKey = "\(storeName.lowercased())|\(barcodeValue)"
            guard !seenKeys.contains(dedupKey) else {
                throw CardTransferError.duplicateCardsInFile
            }
            seenKeys.insert(dedupKey)
        }
    }

    private static func containsControlCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.controlCharacters.contains(scalar)
        }
    }
}

enum CardTransferError: LocalizedError {
    case emptyFile
    case fileTooLarge
    case unsupportedVersion
    case invalidStoreName
    case invalidBarcode
    case ownerNameTooLong
    case storeNameTooLong
    case barcodeTooLong
    case colorIDTooLong
    case tagTooLong
    case invalidCharacters
    case tooManyCards
    case duplicateCardsInFile
    case emptyBundle

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "Il file selezionato è vuoto."
        case .fileTooLarge:
            return "Il file è troppo grande. Usa un file sotto 250 KB."
        case .unsupportedVersion:
            return "Formato file non supportato. Aggiorna l'app o rigenera il file."
        case .invalidStoreName:
            return "Nome negozio mancante nel file."
        case .invalidBarcode:
            return "Codice a barre mancante nel file."
        case .ownerNameTooLong:
            return "Nome intestatario troppo lungo."
        case .storeNameTooLong:
            return "Nome negozio troppo lungo."
        case .barcodeTooLong:
            return "Codice a barre troppo lungo."
        case .colorIDTooLong:
            return "Identificativo colore non valido."
        case .tagTooLong:
            return "Tag troppo lungo."
        case .invalidCharacters:
            return "Il file contiene caratteri non validi."
        case .tooManyCards:
            return "Il file contiene troppe card (max 100)."
        case .duplicateCardsInFile:
            return "Il file contiene card duplicate."
        case .emptyBundle:
            return "Il file non contiene card da importare."
        }
    }
}

private struct EmptyStateView: View {
    var onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color(red: 0.10, green: 0.45, blue: 0.52))

            Text("Nessuna Card Salvata")
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.primary)

            Text("Aggiungi la prima card fedeltà e portala sempre con te.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                onCreateTapped()
            } label: {
                Label("Aggiungi Card", systemImage: "plus")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.12, green: 0.47, blue: 0.53), in: Capsule())
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .padding()
    }
}

enum CardTagCatalog {
    private static let customTagsKey = "customStoreTags"
    private static let hiddenBuiltInTagsKey = "hiddenBuiltInStoreTags"
    private static let customTagIconPrefix = "customTagIcon::"
    private static let builtInTags: [String] = [
        "Alimentari",
        "Vestiti",
        "Sport",
        "Elettronica",
        "Casa",
        "Beauty",
        "Libri",
        "Altro"
    ]
    static let customIconOptions: [String] = [
        "tag.fill",
        "cart.fill",
        "tshirt.fill",
        "figure.run",
        "desktopcomputer",
        "house.fill",
        "sparkles",
        "book.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "gift.fill",
        "heart.fill"
    ]

    static var all: [String] {
        availableTags(
            customTags: customTags(),
            hiddenBuiltInTags: hiddenBuiltInTags()
        )
    }

    static func availableTags(customTags: [String], hiddenBuiltInTags: [String]) -> [String] {
        var seen = Set<String>()
        var result = [""]
        let hiddenKeys = Set(hiddenBuiltInTags.map { normalizedTag($0).lowercased() })

        for tag in builtInTags where !hiddenKeys.contains(tag.lowercased()) {
            let normalized = normalizedTag(tag)
            guard !normalized.isEmpty else {
                continue
            }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else {
                continue
            }
            result.append(normalized)
        }

        for tag in sanitizeCustomTags(customTags) {
            let normalized = normalizedTag(tag)
            guard !normalized.isEmpty else {
                continue
            }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else {
                continue
            }
            result.append(normalized)
        }

        return result
    }

    static func customTags() -> [String] {
        let storedTags = UserDefaults.standard.array(forKey: customTagsKey) as? [String] ?? []
        return sanitizeCustomTags(storedTags)
    }

    static func saveCustomTags(_ tags: [String]) {
        let sanitized = sanitizeCustomTags(tags)
        UserDefaults.standard.set(sanitized, forKey: customTagsKey)
        removeOrphanCustomTagIcons(validCustomTags: sanitized)
    }

    static func hiddenBuiltInTags() -> [String] {
        let stored = UserDefaults.standard.array(forKey: hiddenBuiltInTagsKey) as? [String] ?? []
        return sanitizeHiddenBuiltInTags(stored)
    }

    static func saveHiddenBuiltInTags(_ tags: [String]) {
        UserDefaults.standard.set(sanitizeHiddenBuiltInTags(tags), forKey: hiddenBuiltInTagsKey)
    }

    static func normalizedTag(_ value: String) -> String {
        CardInputValidator.normalizedTag(value)
    }

    static func containsTag(named value: String) -> Bool {
        let normalized = normalizedTag(value)
        guard !normalized.isEmpty else {
            return false
        }
        return all.contains { $0.lowercased() == normalized.lowercased() }
    }

    static func isBuiltInTag(_ value: String) -> Bool {
        let normalized = normalizedTag(value).lowercased()
        return builtInTags.contains { $0.lowercased() == normalized }
    }

    static func customIconName(for tag: String) -> String? {
        let normalized = normalizedTag(tag)
        guard !normalized.isEmpty else {
            return nil
        }
        let key = customTagIconPrefix + normalized.lowercased()
        return UserDefaults.standard.string(forKey: key)
    }

    static func saveCustomIcon(_ iconName: String, for tag: String) {
        let normalized = normalizedTag(tag)
        guard !normalized.isEmpty else {
            return
        }
        let key = customTagIconPrefix + normalized.lowercased()
        UserDefaults.standard.set(iconName, forKey: key)
    }

    static func removeCustomIcon(for tag: String) {
        let normalized = normalizedTag(tag)
        guard !normalized.isEmpty else {
            return
        }
        let key = customTagIconPrefix + normalized.lowercased()
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func displayName(for value: String) -> String {
        value.isEmpty ? "Nessuno" : value
    }

    static func iconName(for value: String?) -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let customIcon = customIconName(for: normalized) {
            return customIcon
        }

        switch normalized.lowercased() {
        case "alimentari":
            return "cart.fill"
        case "vestiti":
            return "tshirt.fill"
        case "sport":
            return "figure.run"
        case "elettronica":
            return "desktopcomputer"
        case "casa":
            return "house.fill"
        case "beauty":
            return "sparkles"
        case "libri":
            return "book.fill"
        case "altro":
            return "tag.fill"
        default:
            return "building.2.fill"
        }
    }

    private static func sanitizeCustomTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var cleaned: [String] = []
        let builtInKeys = Set(builtInTags.map { $0.lowercased() })

        for rawTag in tags {
            let normalized = normalizedTag(rawTag)
            guard !normalized.isEmpty else {
                continue
            }
            let key = normalized.lowercased()
            guard !builtInKeys.contains(key), seen.insert(key).inserted else {
                continue
            }
            cleaned.append(normalized)
        }

        return cleaned
    }

    private static func sanitizeHiddenBuiltInTags(_ tags: [String]) -> [String] {
        let builtInKeys = Set(builtInTags.map { $0.lowercased() })
        var seen = Set<String>()
        var cleaned: [String] = []

        for rawTag in tags {
            let normalized = normalizedTag(rawTag)
            guard !normalized.isEmpty else {
                continue
            }
            let key = normalized.lowercased()
            guard builtInKeys.contains(key), seen.insert(key).inserted else {
                continue
            }
            cleaned.append(normalized)
        }

        return cleaned
    }

    private static func normalizeTagValue(_ value: String) -> String {
        CardInputValidator.normalizedTag(value)
    }

    private static func removeOrphanCustomTagIcons(validCustomTags: [String]) {
        let validKeys = Set(validCustomTags.map { customTagIconPrefix + $0.lowercased() })
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(customTagIconPrefix) {
            if !validKeys.contains(key) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}

struct StyledTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var monospaced = false
    var helperMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Color(red: 0.16, green: 0.49, blue: 0.53))
                    .frame(width: 18)

                TextField(title, text: $text)
                    .font(monospaced ? .body.monospaced() : .body)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )

            if let helperMessage {
                Text(helperMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }
}

enum AppTheme {
    struct ColorOption: Identifiable {
        let id: String
        let name: String
        let color: Color
    }

    static let screenBackground = LinearGradient(
        colors: [
            Color(uiColor: .systemBackground),
            Color(uiColor: .secondarySystemBackground)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let colorOptions: [ColorOption] = [
        ColorOption(id: "", name: "Automatico", color: Color(uiColor: .secondaryLabel)),
        ColorOption(id: "blue", name: "Blu", color: Color(red: 0.11, green: 0.49, blue: 0.73)),
        ColorOption(id: "green", name: "Verde", color: Color(red: 0.14, green: 0.55, blue: 0.45)),
        ColorOption(id: "teal", name: "Turchese", color: Color(red: 0.11, green: 0.56, blue: 0.58)),
        ColorOption(id: "mint", name: "Menta", color: Color(red: 0.26, green: 0.67, blue: 0.55)),
        ColorOption(id: "orange", name: "Arancio", color: Color(red: 0.75, green: 0.42, blue: 0.23)),
        ColorOption(id: "yellow", name: "Giallo", color: Color(red: 0.82, green: 0.64, blue: 0.16)),
        ColorOption(id: "red", name: "Rosso", color: Color(red: 0.72, green: 0.26, blue: 0.28)),
        ColorOption(id: "rose", name: "Rosa", color: Color(red: 0.74, green: 0.33, blue: 0.48)),
        ColorOption(id: "purple", name: "Viola", color: Color(red: 0.48, green: 0.32, blue: 0.72)),
        ColorOption(id: "indigo", name: "Indaco", color: Color(red: 0.32, green: 0.35, blue: 0.74)),
        ColorOption(id: "brown", name: "Marrone", color: Color(red: 0.53, green: 0.38, blue: 0.28)),
        ColorOption(id: "graphite", name: "Grafite", color: Color(red: 0.33, green: 0.36, blue: 0.40))
    ]

    static func tint(for card: Item) -> Color {
        if !card.colorID.isEmpty, let selected = colorOptions.first(where: { $0.id == card.colorID }) {
            return selected.color
        }

        let selectable = colorOptions.filter { !$0.id.isEmpty }
        let sum = card.storeName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return selectable[sum % selectable.count].color
    }
}

enum BarcodeGenerator {
    static func makeCode128(from value: String) -> UIImage? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard CardInputValidator.isValidCode128Input(trimmed) else {
            return nil
        }

        let data = Data(trimmed.utf8)
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = data

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 3, y: 3))
        let context = CIContext()

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
