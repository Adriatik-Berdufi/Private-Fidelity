import Foundation

struct DemoCardData {
    let ownerName: String
    let storeName: String
    let barcodeValue: String
}

enum DemoCardSeed {
    static let cards: [DemoCardData] = [
        DemoCardData(ownerName: "Mario Rossi", storeName: "Esselunga", barcodeValue: "8001234567001"),
        DemoCardData(ownerName: "", storeName: "Conad", barcodeValue: "8001234567002"),
        DemoCardData(ownerName: "Giulia Bianchi", storeName: "Carrefour", barcodeValue: "8001234567003"),
        DemoCardData(ownerName: "", storeName: "Coop", barcodeValue: "8001234567004"),
        DemoCardData(ownerName: "Luca Neri", storeName: "Lidl", barcodeValue: "8001234567005"),
        DemoCardData(ownerName: "Anna Verdi", storeName: "MD", barcodeValue: "8001234567006"),
        DemoCardData(ownerName: "", storeName: "Unes", barcodeValue: "8001234567007"),
        DemoCardData(ownerName: "Sara Conti", storeName: "Decathlon", barcodeValue: "8001234567008"),
        DemoCardData(ownerName: "Paolo Fontana", storeName: "MediaWorld", barcodeValue: "8001234567009"),
        DemoCardData(ownerName: "", storeName: "Iper", barcodeValue: "8001234567010"),
        DemoCardData(ownerName: "Davide Moretti", storeName: "Pam", barcodeValue: "8001234567011"),
        DemoCardData(ownerName: "Francesca Sala", storeName: "Eurospin", barcodeValue: "8001234567012"),
        DemoCardData(ownerName: "", storeName: "Bennet", barcodeValue: "8001234567013"),
        DemoCardData(ownerName: "Marta Riva", storeName: "Aldi", barcodeValue: "8001234567014"),
        DemoCardData(ownerName: "Alessio Grassi", storeName: "NaturaSi", barcodeValue: "8001234567015"),
        DemoCardData(ownerName: "", storeName: "Ikea", barcodeValue: "8001234567016"),
        DemoCardData(ownerName: "Elena Greco", storeName: "Sephora", barcodeValue: "8001234567017"),
        DemoCardData(ownerName: "Marco Villa", storeName: "OVS", barcodeValue: "8001234567018"),
        DemoCardData(ownerName: "", storeName: "Zara", barcodeValue: "8001234567019"),
        DemoCardData(ownerName: "Roberto Ferri", storeName: "H&M", barcodeValue: "8001234567020"),
        DemoCardData(ownerName: "Irene Rizzi", storeName: "Primark", barcodeValue: "8001234567021"),
        DemoCardData(ownerName: "", storeName: "Uniqlo", barcodeValue: "8001234567022"),
        DemoCardData(ownerName: "Stefano Ricci", storeName: "Feltrinelli", barcodeValue: "8001234567023"),
        DemoCardData(ownerName: "Chiara Donati", storeName: "Mondadori", barcodeValue: "8001234567024"),
        DemoCardData(ownerName: "", storeName: "Leroy Merlin", barcodeValue: "8001234567025"),
        DemoCardData(ownerName: "Federico Longo", storeName: "Brico", barcodeValue: "8001234567026"),
        DemoCardData(ownerName: "Silvia Leone", storeName: "Euronics", barcodeValue: "8001234567027"),
        DemoCardData(ownerName: "", storeName: "Trony", barcodeValue: "8001234567028"),
        DemoCardData(ownerName: "Giorgia Pini", storeName: "Foot Locker", barcodeValue: "8001234567029"),
        DemoCardData(ownerName: "Tommaso Carli", storeName: "GameStop", barcodeValue: "8001234567030")
    ]
}
