import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [Item]
    @AppStorage("defaultOwnerName") private var savedDefaultOwnerName = ""

    @State private var draftDefaultOwnerName = ""
    @State private var ownerNameLimitMessage: String?

    @State private var draftCustomTags: [String] = []
    @State private var draftHiddenBuiltInTags: [String] = []
    @State private var draftTagIcons: [String: String] = [:]
    @State private var pendingAddedTags: [String] = []

    @State private var newTagName = ""
    @State private var newTagIconName = "tag.fill"
    @State private var tagLimitMessage: String?
    @State private var hasLoadedInitialState = false
    @State private var isShowingDeleteTags = false
    @State private var isShowingDeleteCards = false
    @State private var pendingDeletedCardIDs: Set<PersistentIdentifier> = []
    @State private var pendingAddedCards: [PendingCardDraft] = []
    @State private var pendingEditedCards: [PersistentIdentifier: PendingCardDraft] = [:]
    @State private var pendingDeletedTags: Set<String> = []
    @State private var pendingTagRenames: [TagRename] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Dati predefiniti") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Nome intestatario", text: $draftDefaultOwnerName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()

                        if let ownerNameLimitMessage {
                            Text(ownerNameLimitMessage)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text("Questo nome verrà proposto automaticamente quando aggiungi una nuova card.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        isShowingDeleteTags = true
                    } label: {
                        Label("Modifica tag", systemImage: "pencil")
                    }
                    .disabled(availableTagsForDeletion.isEmpty)
                }

                if !pendingTagSummaryEntries.isEmpty {
                    Section("Riepilogo Modifica Tag") {
                        ForEach(pendingTagSummaryEntries) { entry in
                            Text(entry.text)
                                .font(.footnote)
                                .foregroundStyle(summaryTextColor(for: entry.kind))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                    }
                }

                Section {
                    Button {
                        isShowingDeleteCards = true
                    } label: {
                        Label("Modifica card", systemImage: "pencil")
                    }
                    .disabled(cards.isEmpty)
                }

                if !pendingCardSummaryEntries.isEmpty {
                    Section("Riepilogo Modifica Card") {
                        ForEach(pendingCardSummaryEntries) { entry in
                            Text(entry.text)
                                .font(.footnote)
                                .foregroundStyle(summaryTextColor(for: entry.kind))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveChangesAndClose()
                    }
                    .disabled(!hasUnsavedChanges)
                }
            }
            .sheet(isPresented: $isShowingDeleteTags) {
                DeleteTagsTableView(
                    tags: availableTagsForDeletion,
                    pendingDeletedTags: $pendingDeletedTags,
                    iconForTag: { tag in
                        icon(for: tag)
                    },
                    onRenameTag: { oldTag, newTag, iconName in
                        renameTag(oldTag: oldTag, to: newTag, iconName: iconName)
                    },
                    onAddTag: { tag, iconName in
                        addTagFromTable(tag, iconName: iconName)
                    }
                )
            }
            .sheet(isPresented: $isShowingDeleteCards) {
                DeleteCardsTableView(
                    cards: cards,
                    pendingDeletedCardIDs: $pendingDeletedCardIDs,
                    pendingAddedCards: $pendingAddedCards,
                    pendingEditedCards: $pendingEditedCards
                )
            }
            .onAppear {
                guard !hasLoadedInitialState else { return }
                loadInitialState()
                hasLoadedInitialState = true
            }
            .onChange(of: draftDefaultOwnerName) { _, newValue in
                let limited = String(newValue.prefix(CardInputLimits.ownerName))
                if limited != newValue {
                    draftDefaultOwnerName = limited
                    ownerNameLimitMessage = "Hai superato il massimo di \(CardInputLimits.ownerName) caratteri."
                    return
                }
                if limited.count < CardInputLimits.ownerName {
                    ownerNameLimitMessage = nil
                }
            }
            .onChange(of: newTagName) { _, newValue in
                CardInputValidator.enforceTextLimit(
                    text: &newTagName,
                    newValue: newValue,
                    limit: CardInputLimits.tag,
                    message: &tagLimitMessage
                )
            }
        }
    }

    private struct TagRename {
        let oldTag: String
        var newTag: String
    }

    private enum SummaryKind {
        case added
        case modified
        case deleted
    }

    private struct SummaryEntry: Identifiable {
        let id = UUID()
        let text: String
        let kind: SummaryKind
    }

    private var savedOwnerNameNormalized: String {
        String(savedDefaultOwnerName.prefix(CardInputLimits.ownerName))
    }

    private var savedCustomTags: [String] {
        CardTagCatalog.customTags()
    }

    private var savedHiddenBuiltInTags: [String] {
        CardTagCatalog.hiddenBuiltInTags()
    }

    private var savedTagIcons: [String: String] {
        Dictionary(
            uniqueKeysWithValues: savedCustomTags.map { tag in
                (tag, CardTagCatalog.customIconName(for: tag) ?? "tag.fill")
            }
        )
    }

    private var currentTagIcons: [String: String] {
        Dictionary(
            uniqueKeysWithValues: draftCustomTags.map { tag in
                let selected = draftTagIcons[tag] ?? "tag.fill"
                let safeIcon = CardTagCatalog.customIconOptions.contains(selected) ? selected : "tag.fill"
                return (tag, safeIcon)
            }
        )
    }

    private var hasUnsavedChanges: Bool {
        savedOwnerNameNormalized != draftDefaultOwnerName ||
        savedCustomTags != draftCustomTags ||
        savedHiddenBuiltInTags != draftHiddenBuiltInTags ||
        savedTagIcons != currentTagIcons ||
        !pendingDeletedCardIDs.isEmpty ||
        !pendingAddedCards.isEmpty ||
        !pendingEditedCards.isEmpty ||
        !pendingDeletedTags.isEmpty ||
        !pendingTagRenames.isEmpty
    }

    private var currentAvailableTags: [String] {
        CardTagCatalog.availableTags(
            customTags: draftCustomTags,
            hiddenBuiltInTags: draftHiddenBuiltInTags
        )
    }

    private var availableTagsForDeletion: [String] {
        currentAvailableTags.filter { !$0.isEmpty }
    }

    private var tagValidationMessage: String? {
        CardInputValidator.customTagValidationMessage(
            tagText: newTagName,
            limitMessage: tagLimitMessage,
            existingTags: currentAvailableTags + pendingAddedTags
        )
    }

    private var pendingTagSummaryEntries: [SummaryEntry] {
        var entries: [SummaryEntry] = []

        let added = pendingAddedTags
            .map { SummaryEntry(text: "Aggiungi tag: \($0)", kind: .added) }
        let renamed = pendingTagRenames
            .map { SummaryEntry(text: "Rinomina tag: \($0.oldTag) -> \($0.newTag)", kind: .modified) }
        let deleted = pendingDeletedTags
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { SummaryEntry(text: "Elimina tag: \($0)", kind: .deleted) }

        let addedKeys = Set(pendingAddedTags.map { CardTagCatalog.normalizedTag($0).lowercased() })
        let deletedKeys = Set(pendingDeletedTags.map { CardTagCatalog.normalizedTag($0).lowercased() })
        let renamedKeys = Set(
            pendingTagRenames.flatMap {
                [
                    CardTagCatalog.normalizedTag($0.oldTag).lowercased(),
                    CardTagCatalog.normalizedTag($0.newTag).lowercased()
                ]
            }
        )

        let savedAvailableTags = CardTagCatalog.availableTags(
            customTags: savedCustomTags,
            hiddenBuiltInTags: savedHiddenBuiltInTags
        )

        let iconChanged = savedAvailableTags
            .filter { !$0.isEmpty }
            .compactMap { tag -> SummaryEntry? in
                let key = CardTagCatalog.normalizedTag(tag).lowercased()
                guard !addedKeys.contains(key), !deletedKeys.contains(key), !renamedKeys.contains(key) else {
                    return nil
                }

                let currentIcon = icon(for: tag)
                let savedIcon: String = {
                    if let icon = savedTagIcons[tag], CardTagCatalog.customIconOptions.contains(icon) {
                        return icon
                    }
                    if let icon = CardTagCatalog.customIconName(for: tag), CardTagCatalog.customIconOptions.contains(icon) {
                        return icon
                    }
                    return CardTagCatalog.iconName(for: tag)
                }()

                guard currentIcon != savedIcon else {
                    return nil
                }

                return SummaryEntry(
                    text: "Cambia icona tag: \(tag) (\(iconLabel(for: savedIcon)) -> \(iconLabel(for: currentIcon)))",
                    kind: .modified
                )
            }

        entries.append(contentsOf: added)
        entries.append(contentsOf: renamed)
        entries.append(contentsOf: iconChanged)
        entries.append(contentsOf: deleted)

        return entries
    }

    private var pendingCardSummaryEntries: [SummaryEntry] {
        var entries: [SummaryEntry] = []

        let colorName: (String) -> String = { colorID in
            AppTheme.colorOptions.first(where: { $0.id == colorID })?.name ?? colorID
        }
        let tagName: (String) -> String = { tag in
            CardTagCatalog.displayName(for: tag)
        }

        let added = pendingAddedCards.map {
            SummaryEntry(text: "Aggiungi card: \($0.storeName) (\($0.barcodeValue))", kind: .added)
        }

        let edited = pendingEditedCards.compactMap { id, draft -> SummaryEntry? in
            guard let original = cards.first(where: { $0.persistentModelID == id }) else {
                return nil
            }

            var changes: [String] = []

            if original.ownerName != draft.ownerName {
                changes.append("Intestatario: \(original.ownerName) -> \(draft.ownerName)")
            }
            if original.storeName != draft.storeName {
                changes.append("Negozio: \(original.storeName) -> \(draft.storeName)")
            }
            if original.barcodeValue != draft.barcodeValue {
                changes.append("Codice: \(original.barcodeValue) -> \(draft.barcodeValue)")
            }

            let originalPoints = original.points ?? 0
            if originalPoints != draft.points {
                changes.append("Punti: \(originalPoints) -> \(draft.points)")
            }

            let originalTag = original.tag ?? ""
            if originalTag != draft.tag {
                changes.append("Tag: \(tagName(originalTag)) -> \(tagName(draft.tag))")
            }

            if original.colorID != draft.colorID {
                changes.append("Colore: \(colorName(original.colorID)) -> \(colorName(draft.colorID))")
            }

            guard !changes.isEmpty else {
                return nil
            }

            let title = draft.storeName.isEmpty ? original.storeName : draft.storeName
            return SummaryEntry(
                text: "Modifica card: \(title) - \(changes.joined(separator: " | "))",
                kind: .modified
            )
        }

        let deleted = cards
            .filter { pendingDeletedCardIDs.contains($0.persistentModelID) }
            .map { SummaryEntry(text: "Elimina card: \($0.storeName) (\($0.barcodeValue))", kind: .deleted) }

        entries.append(contentsOf: added)
        entries.append(contentsOf: edited)
        entries.append(contentsOf: deleted)

        return entries
    }

    private func summaryTextColor(for kind: SummaryKind) -> Color {
        switch kind {
        case .added:
            return .green
        case .modified:
            return .orange
        case .deleted:
            return .red
        }
    }


    private func loadInitialState() {
        draftDefaultOwnerName = savedOwnerNameNormalized
        draftCustomTags = savedCustomTags
        draftHiddenBuiltInTags = savedHiddenBuiltInTags
        draftTagIcons = savedTagIcons
        pendingAddedTags = []
        pendingDeletedCardIDs = []
        pendingAddedCards = []
        pendingEditedCards = [:]
        pendingDeletedTags = []
        pendingTagRenames = []
    }

    private func saveChangesAndClose() {
        savedDefaultOwnerName = String(draftDefaultOwnerName.prefix(CardInputLimits.ownerName))

        applyPendingTagRenamesToCards()
        applyPendingTagDeletions()

        CardTagCatalog.saveHiddenBuiltInTags(draftHiddenBuiltInTags)
        CardTagCatalog.saveCustomTags(draftCustomTags)

        let persistedCustomTags = CardTagCatalog.customTags()
        for tag in persistedCustomTags {
            let icon = draftTagIcons[tag] ?? "tag.fill"
            let safeIcon = CardTagCatalog.customIconOptions.contains(icon) ? icon : "tag.fill"
            CardTagCatalog.saveCustomIcon(safeIcon, for: tag)
        }

        applyPendingCardEdits()
        applyPendingCardDeletions()
        applyPendingCardAdditions()

        pendingAddedTags = []
        pendingDeletedCardIDs.removeAll()
        pendingAddedCards.removeAll()
        pendingEditedCards.removeAll()
        pendingDeletedTags.removeAll()
        pendingTagRenames.removeAll()
        dismiss()
    }

    private func addTag() {
        let normalized = CardInputValidator.normalizedTag(newTagName)
        guard !normalized.isEmpty, tagValidationMessage == nil else {
            return
        }

        _ = addTagFromTable(normalized, iconName: newTagIconName)
        newTagName = ""
        newTagIconName = "tag.fill"
        tagLimitMessage = nil
    }

    @discardableResult
    private func addTagFromTable(_ rawTag: String, iconName: String = "tag.fill") -> Bool {
        let normalized = CardTagCatalog.normalizedTag(rawTag)
        guard !normalized.isEmpty, normalized.count <= CardInputLimits.tag else {
            return false
        }

        let normalizedKey = normalized.lowercased()
        let alreadyExists = currentAvailableTags.contains {
            CardTagCatalog.normalizedTag($0).lowercased() == normalizedKey
        }
        guard !alreadyExists else {
            return false
        }

        let selectedIcon = CardTagCatalog.customIconOptions.contains(iconName) ? iconName : "tag.fill"

        if CardTagCatalog.isBuiltInTag(normalized) {
            draftHiddenBuiltInTags.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        } else {
            draftCustomTags.append(normalized)
            draftTagIcons[normalized] = selectedIcon
            if !pendingAddedTags.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                pendingAddedTags.append(normalized)
            }
        }

        pendingDeletedTags = Set(
            pendingDeletedTags.filter { $0.caseInsensitiveCompare(normalized) != .orderedSame }
        )
        return true
    }

    private func removeTag(_ tag: String) {
        pendingAddedTags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
        pendingDeletedTags.remove(tag)

        if CardTagCatalog.isBuiltInTag(tag) {
            let exists = draftHiddenBuiltInTags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
            if !exists {
                draftHiddenBuiltInTags.append(tag)
            }
            return
        }

        draftCustomTags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
        draftTagIcons.removeValue(forKey: tag)
    }

    private func renameTag(oldTag: String, to newTag: String, iconName: String) {
        let normalizedOld = CardTagCatalog.normalizedTag(oldTag)
        let normalizedNew = CardTagCatalog.normalizedTag(newTag)

        guard !normalizedOld.isEmpty, !normalizedNew.isEmpty else {
            return
        }

        guard normalizedNew.count <= CardInputLimits.tag else {
            return
        }

        let safeIcon = CardTagCatalog.customIconOptions.contains(iconName) ? iconName : "tag.fill"

        let oldKey = normalizedOld.lowercased()
        let newKey = normalizedNew.lowercased()

        if oldKey == newKey {
            draftTagIcons[normalizedOld] = safeIcon
            return
        }

        let alreadyExists = currentAvailableTags.contains {
            CardTagCatalog.normalizedTag($0).lowercased() == newKey
        }
        guard !alreadyExists else {
            return
        }

        pendingAddedTags = pendingAddedTags.map {
            $0.caseInsensitiveCompare(normalizedOld) == .orderedSame ? normalizedNew : $0
        }

        if CardTagCatalog.isBuiltInTag(normalizedOld) {
            let isHidden = draftHiddenBuiltInTags.contains { $0.caseInsensitiveCompare(normalizedOld) == .orderedSame }
            if !isHidden {
                draftHiddenBuiltInTags.append(normalizedOld)
            }
            if !draftCustomTags.contains(where: { $0.caseInsensitiveCompare(normalizedNew) == .orderedSame }) {
                draftCustomTags.append(normalizedNew)
            }
        } else {
            if let index = draftCustomTags.firstIndex(where: { $0.caseInsensitiveCompare(normalizedOld) == .orderedSame }) {
                draftCustomTags[index] = normalizedNew
            }
        }

        draftTagIcons.removeValue(forKey: normalizedOld)
        draftTagIcons[normalizedNew] = safeIcon

        pendingDeletedTags.remove(normalizedOld)

        recordTagRename(from: normalizedOld, to: normalizedNew)
    }

    private func recordTagRename(from oldTag: String, to newTag: String) {
        let oldKey = CardTagCatalog.normalizedTag(oldTag).lowercased()
        let newNormalized = CardTagCatalog.normalizedTag(newTag)
        let newKey = newNormalized.lowercased()

        guard !oldKey.isEmpty, !newKey.isEmpty, oldKey != newKey else {
            return
        }

        if let index = pendingTagRenames.firstIndex(where: { CardTagCatalog.normalizedTag($0.newTag).lowercased() == oldKey }) {
            pendingTagRenames[index].newTag = newNormalized
            return
        }

        if let index = pendingTagRenames.firstIndex(where: { CardTagCatalog.normalizedTag($0.oldTag).lowercased() == oldKey }) {
            pendingTagRenames[index].newTag = newNormalized
            return
        }

        pendingTagRenames.append(TagRename(oldTag: oldTag, newTag: newNormalized))
    }

    private func applyPendingTagRenamesToCards() {
        guard !pendingTagRenames.isEmpty else {
            return
        }

        for card in cards {
            guard let tagValue = card.tag else {
                continue
            }

            let normalizedCardTag = CardTagCatalog.normalizedTag(tagValue).lowercased()
            guard let rename = pendingTagRenames.first(where: {
                CardTagCatalog.normalizedTag($0.oldTag).lowercased() == normalizedCardTag
            }) else {
                continue
            }

            card.tag = rename.newTag
        }
    }

    private func applyPendingTagDeletions() {
        guard !pendingDeletedTags.isEmpty else {
            return
        }

        for tag in availableTagsForDeletion where pendingDeletedTags.contains(tag) {
            removeTag(tag)
        }
    }

    private func applyPendingCardEdits() {
        guard !pendingEditedCards.isEmpty else {
            return
        }

        for card in cards {
            guard let draft = pendingEditedCards[card.persistentModelID] else {
                continue
            }
            card.ownerName = draft.ownerName
            card.storeName = draft.storeName
            card.barcodeValue = draft.barcodeValue
            card.points = draft.points
            card.tag = draft.tag
            card.colorID = draft.colorID
        }
    }

    private func applyPendingCardDeletions() {
        guard !pendingDeletedCardIDs.isEmpty else {
            return
        }

        withAnimation {
            for card in cards where pendingDeletedCardIDs.contains(card.persistentModelID) {
                modelContext.delete(card)
            }
        }
    }

    private func applyPendingCardAdditions() {
        guard !pendingAddedCards.isEmpty else {
            return
        }

        var usedBarcodes = Set(cards.map {
            $0.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
        })
        var nextSortOrder = (cards.map(\.sortOrder).max() ?? -1) + 1

        for draft in pendingAddedCards {
            let normalizedBarcode = draft.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !usedBarcodes.contains(normalizedBarcode) else {
                continue
            }

            let item = Item(
                ownerName: draft.ownerName,
                storeName: draft.storeName,
                barcodeValue: normalizedBarcode,
                tag: draft.tag,
                points: draft.points,
                sortOrder: nextSortOrder,
                colorID: draft.colorID
            )
            modelContext.insert(item)
            usedBarcodes.insert(normalizedBarcode)
            nextSortOrder += 1
        }
    }

    private func iconBinding(for tag: String) -> Binding<String> {
        Binding(
            get: { icon(for: tag) },
            set: { newIcon in
                draftTagIcons[tag] = newIcon
            }
        )
    }

    private func icon(for tag: String) -> String {
        if let selected = draftTagIcons[tag], CardTagCatalog.customIconOptions.contains(selected) {
            return selected
        }

        if let savedCustomIcon = CardTagCatalog.customIconName(for: tag), CardTagCatalog.customIconOptions.contains(savedCustomIcon) {
            return savedCustomIcon
        }

        return CardTagCatalog.iconName(for: tag)
    }

    private func iconLabel(for iconName: String) -> String {
        switch iconName {
        case "tag.fill": return "Generico"
        case "cart.fill": return "Spesa"
        case "tshirt.fill": return "Vestiti"
        case "figure.run": return "Sport"
        case "desktopcomputer": return "Elettronica"
        case "house.fill": return "Casa"
        case "sparkles": return "Beauty"
        case "book.fill": return "Libri"
        case "fork.knife": return "Ristorante"
        case "cup.and.saucer.fill": return "Caffè"
        case "gift.fill": return "Regali"
        case "heart.fill": return "Benessere"
        default: return iconName
        }
    }
}

private struct DeleteCardsTableView: View {
    @Environment(\.dismiss) private var dismiss

    let cards: [Item]
    @Binding var pendingDeletedCardIDs: Set<PersistentIdentifier>
    @Binding var pendingAddedCards: [PendingCardDraft]
    @Binding var pendingEditedCards: [PersistentIdentifier: PendingCardDraft]

    @State private var editingCardID: PersistentIdentifier?
    @State private var isPresentingEditCard = false
    @State private var isPresentingAddCard = false
    @State private var isAscendingOrder = true

    private var sortedCards: [Item] {
        cards.sorted { lhs, rhs in
            let lhsStore = displayStoreName(for: lhs)
            let rhsStore = displayStoreName(for: rhs)
            let storeCompare = lhsStore.localizedCaseInsensitiveCompare(rhsStore)

            let lhsOwner = displayOwnerName(for: lhs)
            let rhsOwner = displayOwnerName(for: rhs)
            let ownerCompare = lhsOwner.localizedCaseInsensitiveCompare(rhsOwner)

            let result: ComparisonResult
            if storeCompare == .orderedSame {
                result = ownerCompare
            } else {
                result = storeCompare
            }

            if isAscendingOrder {
                return result == .orderedAscending
            }
            return result == .orderedDescending
        }
    }

    private var allCardIDs: Set<PersistentIdentifier> {
        Set(sortedCards.map(\.persistentModelID))
    }

    private var allMarkedForDeletion: Bool {
        !allCardIDs.isEmpty && allCardIDs.isSubset(of: pendingDeletedCardIDs)
    }

    private var editingCard: Item? {
        guard let editingCardID else {
            return nil
        }
        return cards.first { $0.persistentModelID == editingCardID }
    }

    private var isEditingCardSheetPresented: Binding<Bool> {
        Binding(
            get: { isPresentingEditCard && editingCard != nil },
            set: { newValue in
                if !newValue {
                    isPresentingEditCard = false
                    editingCardID = nil
                }
            }
        )
    }

    private func displayStoreName(for card: Item) -> String {
        pendingEditedCards[card.persistentModelID]?.storeName ?? card.storeName
    }

    private func displayOwnerName(for card: Item) -> String {
        pendingEditedCards[card.persistentModelID]?.ownerName ?? card.ownerName
    }

    private func displayBarcode(for card: Item) -> String {
        pendingEditedCards[card.persistentModelID]?.barcodeValue ?? card.barcodeValue
    }

    private var blockedBarcodesForDraftAdd: Set<String> {
        let existing = cards.map {
            (pendingEditedCards[$0.persistentModelID]?.barcodeValue ?? $0.barcodeValue)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let pending = pendingAddedCards.map { $0.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Set(existing + pending)
    }

    private func iconLabel(for iconName: String) -> String {
        switch iconName {
        case "tag.fill": return "Generico"
        case "cart.fill": return "Spesa"
        case "tshirt.fill": return "Vestiti"
        case "figure.run": return "Sport"
        case "desktopcomputer": return "Elettronica"
        case "house.fill": return "Casa"
        case "sparkles": return "Beauty"
        case "book.fill": return "Libri"
        case "fork.knife": return "Ristorante"
        case "cup.and.saucer.fill": return "Caffè"
        case "gift.fill": return "Regali"
        case "heart.fill": return "Benessere"
        default: return iconName
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if allMarkedForDeletion {
                            pendingDeletedCardIDs.subtract(allCardIDs)
                        } else {
                            pendingDeletedCardIDs.formUnion(allCardIDs)
                        }
                    } label: {
                        Label(
                            allMarkedForDeletion ? "Ripristina tutte le card" : "Elimina tutte le card",
                            systemImage: allMarkedForDeletion ? "arrow.uturn.backward.circle.fill" : "trash.fill"
                        )
                        .foregroundStyle(allMarkedForDeletion ? .orange : .red)
                    }
                    .disabled(sortedCards.isEmpty)
                }

                Section {
                    if sortedCards.isEmpty {
                        Text("Nessuna card disponibile.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedCards, id: \.persistentModelID) { card in
                            let isPending = pendingDeletedCardIDs.contains(card.persistentModelID)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayStoreName(for: card))
                                        .strikethrough(isPending)
                                    Text(displayBarcode(for: card))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .strikethrough(isPending)
                                }

                                Spacer()

                                Button {
                                    editingCardID = card.persistentModelID
                                    isPresentingEditCard = true
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    if isPending {
                                        pendingDeletedCardIDs.remove(card.persistentModelID)
                                    } else {
                                        pendingDeletedCardIDs.insert(card.persistentModelID)
                                    }
                                } label: {
                                    Image(systemName: isPending ? "arrow.uturn.backward.circle" : "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Card")
                        Spacer()
                        Button {
                            isAscendingOrder.toggle()
                        } label: {
                            Label(
                                isAscendingOrder ? "A-Z" : "Z-A",
                                systemImage: "arrow.up.arrow.down.circle"
                            )
                            .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.plain)
                    }
                    .textCase(nil)
                }
            }
            .navigationTitle("Modifica card")
            .sheet(isPresented: isEditingCardSheetPresented) {
                if let editingCard {
                    PendingEditCardView(
                        initialDraft: PendingCardDraft(
                            ownerName: pendingEditedCards[editingCard.persistentModelID]?.ownerName ?? editingCard.ownerName,
                            storeName: pendingEditedCards[editingCard.persistentModelID]?.storeName ?? editingCard.storeName,
                            barcodeValue: pendingEditedCards[editingCard.persistentModelID]?.barcodeValue ?? editingCard.barcodeValue,
                            points: pendingEditedCards[editingCard.persistentModelID]?.points ?? (editingCard.points ?? 0),
                            tag: pendingEditedCards[editingCard.persistentModelID]?.tag ?? (editingCard.tag ?? ""),
                            colorID: pendingEditedCards[editingCard.persistentModelID]?.colorID ?? editingCard.colorID
                        ),
                        blockedBarcodes: Set(
                            cards
                                .filter { $0.persistentModelID != editingCard.persistentModelID }
                                .map { pendingEditedCards[$0.persistentModelID]?.barcodeValue ?? $0.barcodeValue }
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        ).union(
                            Set(pendingAddedCards.map { $0.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines) })
                        ),
                        onSave: { updatedDraft in
                            pendingEditedCards[editingCard.persistentModelID] = updatedDraft
                        }
                    )
                }
            }
            .sheet(isPresented: $isPresentingAddCard) {
                AddCardView(
                    blockedBarcodes: blockedBarcodesForDraftAdd,
                    onSaveDraft: { draft in
                        pendingAddedCards.append(draft)
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddCard = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

private struct PendingEditCardView: View {
    @Environment(\.dismiss) private var dismiss

    let initialDraft: PendingCardDraft
    let blockedBarcodes: Set<String>
    let onSave: (PendingCardDraft) -> Void

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

    init(initialDraft: PendingCardDraft, blockedBarcodes: Set<String>, onSave: @escaping (PendingCardDraft) -> Void) {
        self.initialDraft = initialDraft
        self.blockedBarcodes = blockedBarcodes
        self.onSave = onSave

        _draftOwnerName = State(initialValue: initialDraft.ownerName)
        _draftStoreName = State(initialValue: initialDraft.storeName)
        _draftBarcodeValue = State(initialValue: initialDraft.barcodeValue)
        _draftPointsText = State(initialValue: "\(initialDraft.points)")
        _draftTag = State(initialValue: initialDraft.tag)
        _draftColorID = State(initialValue: initialDraft.colorID)
        _previousDraftBarcodeValue = State(initialValue: initialDraft.barcodeValue)
    }

    private var normalizedBarcodeValue: String {
        draftBarcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var pointsValidationMessage: String? {
        CardInputValidator.pointsValidationMessage(
            pointsText: draftPointsText,
            limitMessage: pointsLimitMessage
        )
    }

    private var barcodeValidationMessage: String? {
        CardInputValidator.barcodeValidationMessage(
            barcodeText: normalizedBarcodeValue,
            limitMessage: barcodeLimitMessage
        )
    }

    private var hasDuplicateBarcode: Bool {
        blockedBarcodes.contains(normalizedBarcodeValue)
    }

    private var isFormValid: Bool {
        ownerLimitMessage == nil &&
        storeLimitMessage == nil &&
        barcodeValidationMessage == nil &&
        !draftStoreName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !normalizedBarcodeValue.isEmpty &&
        CardInputValidator.isValidCode128Input(normalizedBarcodeValue) &&
        pointsValidationMessage == nil &&
        !hasDuplicateBarcode
    }

    private var parsedPoints: Int {
        max(0, Int(draftPointsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
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
                            if hasDuplicateBarcode {
                                Text("Questo codice QR è già presente.")
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
                        onSave(
                            PendingCardDraft(
                                ownerName: draftOwnerName.trimmingCharacters(in: .whitespacesAndNewlines),
                                storeName: draftStoreName.trimmingCharacters(in: .whitespacesAndNewlines),
                                barcodeValue: normalizedBarcodeValue,
                                points: parsedPoints,
                                tag: draftTag,
                                colorID: draftColorID
                            )
                        )
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
}

private struct DeleteTagsTableView: View {
    @Environment(\.dismiss) private var dismiss

    let tags: [String]
    @Binding var pendingDeletedTags: Set<String>
    let iconForTag: (String) -> String
    let onRenameTag: (String, String, String) -> Void
    let onAddTag: (String, String) -> Bool

    @State private var editingTag: String?
    @State private var editedTagText = ""
    @State private var editedTagIconName = "tag.fill"
    @State private var isShowingEditTagSheet = false
    @State private var isShowingAddTagSheet = false
    @State private var newTagText = ""
    @State private var newTagIconName = "tag.fill"
    @State private var isAscendingOrder = true

    private var sortedTags: [String] {
        tags.sorted { lhs, rhs in
            let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
            if isAscendingOrder {
                return comparison == .orderedAscending
            }
            return comparison == .orderedDescending
        }
    }

    private var allTags: Set<String> {
        Set(sortedTags)
    }

    private var allMarkedForDeletion: Bool {
        !allTags.isEmpty && allTags.isSubset(of: pendingDeletedTags)
    }

    private var canSaveEditedTag: Bool {
        guard let editingTag else {
            return false
        }

        let normalized = CardTagCatalog.normalizedTag(editedTagText)
        let currentNormalized = CardTagCatalog.normalizedTag(editingTag)
        guard !normalized.isEmpty, normalized.count <= CardInputLimits.tag else {
            return false
        }

        let nameChanged = normalized.lowercased() != currentNormalized.lowercased()
        let iconChanged = editedTagIconName != iconForTag(editingTag)

        if !nameChanged && !iconChanged {
            return false
        }

        if !nameChanged {
            return true
        }

        return !tags.contains(where: {
            $0.caseInsensitiveCompare(normalized) == .orderedSame &&
            $0.caseInsensitiveCompare(editingTag) != .orderedSame
        })
    }

    private var canAddNewTag: Bool {
        let normalized = CardTagCatalog.normalizedTag(newTagText)
        guard !normalized.isEmpty, normalized.count <= CardInputLimits.tag else {
            return false
        }

        return !tags.contains { $0.caseInsensitiveCompare(normalized) == .orderedSame }
    }

    private func iconLabel(for iconName: String) -> String {
        switch iconName {
        case "tag.fill": return "Generico"
        case "cart.fill": return "Spesa"
        case "tshirt.fill": return "Vestiti"
        case "figure.run": return "Sport"
        case "desktopcomputer": return "Elettronica"
        case "house.fill": return "Casa"
        case "sparkles": return "Beauty"
        case "book.fill": return "Libri"
        case "fork.knife": return "Ristorante"
        case "cup.and.saucer.fill": return "Caffè"
        case "gift.fill": return "Regali"
        case "heart.fill": return "Benessere"
        default: return iconName
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if allMarkedForDeletion {
                            pendingDeletedTags.subtract(allTags)
                        } else {
                            pendingDeletedTags.formUnion(allTags)
                        }
                    } label: {
                        Label(
                            allMarkedForDeletion ? "Ripristina tutti i tag" : "Elimina tutti i tag",
                            systemImage: allMarkedForDeletion ? "arrow.uturn.backward.circle.fill" : "trash.fill"
                        )
                        .foregroundStyle(allMarkedForDeletion ? .orange : .red)
                    }
                    .disabled(tags.isEmpty)
                }

                Section {
                    if tags.isEmpty {
                        Text("Nessun tag disponibile.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedTags, id: \.self) { tag in
                            let isPending = pendingDeletedTags.contains(tag)

                            HStack(spacing: 12) {
                                Label(tag, systemImage: iconForTag(tag))
                                    .strikethrough(isPending)

                                Spacer()

                                Button {
                                    editingTag = tag
                                    editedTagText = tag
                                    editedTagIconName = iconForTag(tag)
                                    isShowingEditTagSheet = true
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    if isPending {
                                        pendingDeletedTags.remove(tag)
                                    } else {
                                        pendingDeletedTags.insert(tag)
                                    }
                                } label: {
                                    Image(systemName: isPending ? "arrow.uturn.backward.circle" : "trash")
                                        .foregroundStyle(isPending ? .orange : .red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Tag")
                        Spacer()
                        Button {
                            isAscendingOrder.toggle()
                        } label: {
                            Label(
                                isAscendingOrder ? "A-Z" : "Z-A",
                                systemImage: "arrow.up.arrow.down.circle"
                            )
                            .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.plain)
                    }
                    .textCase(nil)
                }
            }
            .navigationTitle("Modifica tag")
            .sheet(isPresented: $isShowingEditTagSheet) {
                NavigationStack {
                    Form {
                        Section("Modifica tag") {
                            TextField("Nome tag", text: $editedTagText)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()

                            Picker("Icona", selection: $editedTagIconName) {
                                ForEach(CardTagCatalog.customIconOptions, id: \.self) { iconName in
                                    Label(iconLabel(for: iconName), systemImage: iconName)
                                        .tag(iconName)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .navigationTitle("Modifica tag")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annulla") {
                                editingTag = nil
                                editedTagText = ""
                                editedTagIconName = "tag.fill"
                                isShowingEditTagSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salva") {
                                guard let editingTag else {
                                    return
                                }
                                onRenameTag(editingTag, editedTagText, editedTagIconName)
                                self.editingTag = nil
                                editedTagText = ""
                                editedTagIconName = "tag.fill"
                                isShowingEditTagSheet = false
                            }
                            .disabled(!canSaveEditedTag)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAddTagSheet) {
                NavigationStack {
                    Form {
                        Section("Nuovo tag") {
                            TextField("Nome tag", text: $newTagText)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()

                            Picker("Icona", selection: $newTagIconName) {
                                ForEach(CardTagCatalog.customIconOptions, id: \.self) { iconName in
                                    Label(iconLabel(for: iconName), systemImage: iconName)
                                        .tag(iconName)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .navigationTitle("Aggiungi tag")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annulla") {
                                newTagText = ""
                                newTagIconName = "tag.fill"
                                isShowingAddTagSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Aggiungi") {
                                let success = onAddTag(newTagText, newTagIconName)
                                if success {
                                    newTagText = ""
                                    newTagIconName = "tag.fill"
                                    isShowingAddTagSheet = false
                                }
                            }
                            .disabled(!canAddNewTag)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddTagSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
