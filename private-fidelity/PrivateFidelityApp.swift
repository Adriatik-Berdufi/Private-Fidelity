//
//  PrivateFidelityApp.swift
//  private-fidelity
//
//  Created by Adriatik Berdufi on 18/04/2026.
//

import SwiftUI
import SwiftData

@main
struct PrivateFidelityApp: App {
    private static let hasSeededDemoCardsKey = "hasSeededDemoCards"
    var sharedModelContainer: ModelContainer = Self.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Item.self,
        ])

        do {
            let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [persistentConfiguration])
            seedDemoCardsIfNeeded(in: container)
            return container
        } catch {
            // Fallback per evitare blocchi all'avvio in caso di store locale non leggibile.
            do {
                let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
                seedDemoCardsIfNeeded(in: container)
                return container
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    private static func seedDemoCardsIfNeeded(in container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: hasSeededDemoCardsKey) else {
            return
        }

        let context = ModelContext(container)

        do {
            let existingCards = try context.fetch(FetchDescriptor<Item>())
            guard existingCards.isEmpty else {
                UserDefaults.standard.set(true, forKey: hasSeededDemoCardsKey)
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
            UserDefaults.standard.set(true, forKey: hasSeededDemoCardsKey)
        } catch {
            print("Demo cards seed failed: \(error.localizedDescription)")
        }
    }
}
