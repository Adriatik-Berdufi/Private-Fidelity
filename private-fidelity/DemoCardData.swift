import Foundation

struct DemoCardData {
    let ownerName: String
    let storeName: String
    let barcodeValue: String
    let tag: String
}

enum DemoCardSeed {
    private static let tagCycle = ["Alimentari", "Vestiti", "Sport", "Elettronica", "Casa", "Beauty", "Libri", "Altro", ""]

    static let cards: [DemoCardData] = rawCards.enumerated().map { index, card in
        DemoCardData(
            ownerName: card.ownerName,
            storeName: card.storeName,
            barcodeValue: card.barcodeValue,
            tag: tagCycle[index % tagCycle.count]
        )
    }

    private static let rawCards: [(ownerName: String, storeName: String, barcodeValue: String)] = [
        ("Mario Rossi", "Esselunga", "8001234567001"),
        ("", "Conad", "8001234567002"),
        ("Giulia Bianchi", "Carrefour", "8001234567003"),
        ("", "Coop", "8001234567004"),
        ("Luca Neri", "Lidl", "8001234567005"),
        ("Anna Verdi", "MD", "8001234567006"),
        ("", "Unes", "8001234567007"),
        ("Sara Conti", "Decathlon", "8001234567008"),
        ("Paolo Fontana", "MediaWorld", "8001234567009"),
        ("", "Iper", "8001234567010"),
        ("Davide Moretti", "Pam", "8001234567011"),
        ("Francesca Sala", "Eurospin", "8001234567012"),
        ("", "Bennet", "8001234567013"),
        ("Marta Riva", "Aldi", "8001234567014"),
        ("Alessio Grassi", "NaturaSi", "8001234567015"),
        ("", "Ikea", "8001234567016"),
        ("Elena Greco", "Sephora", "8001234567017"),
        ("Marco Villa", "OVS", "8001234567018"),
        ("", "Zara", "8001234567019"),
        ("Roberto Ferri", "H&M", "8001234567020"),
        ("Irene Rizzi", "Primark", "8001234567021"),
        ("", "Uniqlo", "8001234567022"),
        ("Stefano Ricci", "Feltrinelli", "8001234567023"),
        ("Chiara Donati", "Mondadori", "8001234567024"),
        ("", "Leroy Merlin", "8001234567025"),
        ("Federico Longo", "Brico", "8001234567026"),
        ("Silvia Leone", "Euronics", "8001234567027"),
        ("", "Trony", "8001234567028"),
        ("Giorgia Pini", "Foot Locker", "8001234567029"),
        ("Tommaso Carli", "GameStop", "8001234567030")
    ]
}
