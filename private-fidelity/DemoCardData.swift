import Foundation

struct DemoCardData {
    let ownerName: String
    let storeName: String
    let barcodeValue: String
    let tag: String
    let points: Int
}

enum DemoCardSeed {
    static let cards: [DemoCardData] = [
        DemoCardData(ownerName: "Mario Rossi", storeName: "Esselunga", barcodeValue: "8001234567001", tag: "Alimentari", points: 126),
        DemoCardData(ownerName: "", storeName: "Conad", barcodeValue: "8001234567002", tag: "Alimentari", points: 52),
        DemoCardData(ownerName: "Giulia Bianchi", storeName: "Carrefour", barcodeValue: "8001234567003", tag: "Alimentari", points: 241),
        DemoCardData(ownerName: "", storeName: "Coop", barcodeValue: "8001234567004", tag: "Alimentari", points: 77),
        DemoCardData(ownerName: "Luca Neri", storeName: "Lidl", barcodeValue: "8001234567005", tag: "Alimentari", points: 33),
        DemoCardData(ownerName: "Anna Verdi", storeName: "MD", barcodeValue: "8001234567006", tag: "Alimentari", points: 18),
        DemoCardData(ownerName: "", storeName: "Unes", barcodeValue: "8001234567007", tag: "Alimentari", points: 95),

        DemoCardData(ownerName: "Sara Conti", storeName: "Decathlon", barcodeValue: "8001234567008", tag: "Sport", points: 312),
        DemoCardData(ownerName: "Paolo Fontana", storeName: "MediaWorld", barcodeValue: "8001234567009", tag: "Elettronica", points: 44),
        DemoCardData(ownerName: "", storeName: "Iper", barcodeValue: "8001234567010", tag: "Alimentari", points: 65),
        DemoCardData(ownerName: "Davide Moretti", storeName: "Pam", barcodeValue: "8001234567011", tag: "Alimentari", points: 109),
        DemoCardData(ownerName: "Francesca Sala", storeName: "Eurospin", barcodeValue: "8001234567012", tag: "Alimentari", points: 21),
        DemoCardData(ownerName: "", storeName: "Bennet", barcodeValue: "8001234567013", tag: "Alimentari", points: 84),
        DemoCardData(ownerName: "Marta Riva", storeName: "Aldi", barcodeValue: "8001234567014", tag: "Alimentari", points: 57),
        DemoCardData(ownerName: "Alessio Grassi", storeName: "NaturaSi", barcodeValue: "8001234567015", tag: "Alimentari", points: 143),

        DemoCardData(ownerName: "", storeName: "Ikea", barcodeValue: "8001234567016", tag: "Casa", points: 26),
        DemoCardData(ownerName: "Elena Greco", storeName: "Sephora", barcodeValue: "8001234567017", tag: "Beauty", points: 188),
        DemoCardData(ownerName: "Marco Villa", storeName: "OVS", barcodeValue: "8001234567018", tag: "Vestiti", points: 49),
        DemoCardData(ownerName: "", storeName: "Zara", barcodeValue: "8001234567019", tag: "Vestiti", points: 71),
        DemoCardData(ownerName: "Roberto Ferri", storeName: "H&M", barcodeValue: "8001234567020", tag: "Vestiti", points: 104),
        DemoCardData(ownerName: "Irene Rizzi", storeName: "Primark", barcodeValue: "8001234567021", tag: "Vestiti", points: 16),
        DemoCardData(ownerName: "", storeName: "Uniqlo", barcodeValue: "8001234567022", tag: "Vestiti", points: 39),

        DemoCardData(ownerName: "Stefano Ricci", storeName: "Feltrinelli", barcodeValue: "8001234567023", tag: "Libri", points: 225),
        DemoCardData(ownerName: "Chiara Donati", storeName: "Mondadori", barcodeValue: "8001234567024", tag: "Libri", points: 119),
        DemoCardData(ownerName: "", storeName: "Leroy Merlin", barcodeValue: "8001234567025", tag: "Casa", points: 53),
        DemoCardData(ownerName: "Federico Longo", storeName: "Brico", barcodeValue: "8001234567026", tag: "Casa", points: 41),
        DemoCardData(ownerName: "Silvia Leone", storeName: "Euronics", barcodeValue: "8001234567027", tag: "Elettronica", points: 67),
        DemoCardData(ownerName: "", storeName: "Trony", barcodeValue: "8001234567028", tag: "Elettronica", points: 28),
        DemoCardData(ownerName: "Giorgia Pini", storeName: "Foot Locker", barcodeValue: "8001234567029", tag: "Sport", points: 136),
        DemoCardData(ownerName: "Tommaso Carli", storeName: "GameStop", barcodeValue: "8001234567030", tag: "Altro", points: 92)
    ]
}
