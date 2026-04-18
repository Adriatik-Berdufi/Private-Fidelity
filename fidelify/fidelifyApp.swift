//
//  fidelifyApp.swift
//  fidelify
//
//  Created by Adriatik Berdufi on 18/04/2026.
//

import SwiftUI
import SwiftData

@main
struct fidelifyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            seedDemoCardsIfNeeded(in: container)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func seedDemoCardsIfNeeded(in container: ModelContainer) {
        let context = ModelContext(container)

        do {
            let existingCards = try context.fetch(FetchDescriptor<Item>())
            guard existingCards.isEmpty else {
                return
            }

            for (index, card) in DemoCardSeed.cards.enumerated() {
                let item = Item(
                    ownerName: card.ownerName,
                    storeName: card.storeName,
                    barcodeValue: card.barcodeValue,
                    sortOrder: index,
                    favoriteOrder: index,
                    isFavorite: index < 6
                )
                context.insert(item)
            }

            try context.save()
        } catch {
            assertionFailure("Demo cards seed failed: \(error.localizedDescription)")
        }
    }
}
