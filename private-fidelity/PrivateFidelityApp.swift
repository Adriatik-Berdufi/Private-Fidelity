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
            ensureApplicationSupportDirectoryExists()
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

    private static func ensureApplicationSupportDirectoryExists() {
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            try FileManager.default.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("Unable to prepare Application Support directory: \(error.localizedDescription)")
        }
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
                    tag: card.tag,
                    sortOrder: index,
                    favoriteOrder: index,
                    isFavorite: index < 6
                )
                context.insert(item)
            }

            try context.save()
        } catch {
            print("Demo cards seed failed: \(error.localizedDescription)")
        }
    }
}
