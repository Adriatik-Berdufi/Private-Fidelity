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
    var tag: String?
    var points: Int?
    var createdAt: Date
    var sortOrder: Int = 0
    var favoriteOrder: Int = 0
    var isFavorite: Bool = false
    var colorID: String = ""

    init(
        ownerName: String,
        storeName: String,
        barcodeValue: String,
        tag: String = "",
        points: Int? = 0,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        favoriteOrder: Int = 0,
        isFavorite: Bool = false,
        colorID: String = ""
    ) {
        self.ownerName = ownerName
        self.storeName = storeName
        self.barcodeValue = barcodeValue
        self.tag = tag
        self.points = points
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.favoriteOrder = favoriteOrder
        self.isFavorite = isFavorite
        self.colorID = colorID
    }
}
