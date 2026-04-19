//
//  Item.swift
//  private-fidelity
//
//  Created by Adriatik Berdufi on 18/04/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var ownerName: String
    var storeName: String
    var barcodeValue: String
    var createdAt: Date
    var sortOrder: Int = 0
    var favoriteOrder: Int = 0
    var isFavorite: Bool = false
    var colorID: String = ""

    init(
        ownerName: String,
        storeName: String,
        barcodeValue: String,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        favoriteOrder: Int = 0,
        isFavorite: Bool = false,
        colorID: String = ""
    ) {
        self.ownerName = ownerName
        self.storeName = storeName
        self.barcodeValue = barcodeValue
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.favoriteOrder = favoriteOrder
        self.isFavorite = isFavorite
        self.colorID = colorID
    }
}
