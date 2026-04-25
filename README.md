# Private Fidelity

App iOS (SwiftUI + SwiftData) per salvare e gestire carte fedeltà in modo privato sul dispositivo.

## Cosa fa l'app

- Salva carte fedeltà con:
  - intestatario
  - nome negozio
  - barcode
  - tag negozio
  - colore card
  - punti
- Mostra le card in Home con:
  - sezione `Preferiti`
  - sezione `Tutte le card`
  - filtro `Tutte / Per Tag`
  - ricerca istantanea per nome negozio
- Dettaglio card con:
  - barcode grande
  - gestione punti (`+` e `-`)
  - modifica card
  - eliminazione card
  - condivisione singola card
- Import/Export card da file (`.private-fidelitycard` / JSON)
- Scanner barcode con fotocamera
- Seed automatico di card demo al primo avvio

## Stack tecnico

- SwiftUI
- SwiftData (persistenza locale)
- AVFoundation (scanner)
- CoreImage (generazione barcode)

## Requisiti

- macOS con Xcode aggiornato
- iOS target compatibile con SwiftData
- Apple Developer account (solo se vuoi installare su iPhone fisico)

## Installazione e avvio

1. Clona il repository.
2. Apri il progetto in Xcode.
3. Seleziona scheme e target app `private-fidelity`.
4. Scegli destinazione:
   - iPhone reale (consigliato per scanner)
   - simulatore (scanner camera non disponibile)
5. Premi `Product > Run` (`Cmd + R`).

## Test rapido funzionale

1. Apri app e verifica caricamento card demo.
2. Aggiungi una nuova card.
3. Prova validazioni campi (limiti caratteri, barcode, punti).
4. Apri dettaglio card, aggiorna punti con `+` e `-`.
5. Testa ricerca in Home.
6. Testa filtro `Per Tag`.
7. Prova export e re-import della stessa card.
8. Prova scanner barcode su iPhone reale.

## Regole validazione principali

- Intestatario: max 40 caratteri
- Negozio: max 20 caratteri
- Barcode: max 128 caratteri + validazione Code128 input
- Punti: solo numeri, max 10 cifre
- Feedback inline sotto i campi quando si supera il limite o input non valido

## Struttura progetto

```text
private-fidelity/
├─ private-fidelity/
│  ├─ Assets.xcassets
│  └─ PrivateFidelityApp.swift
├─ Views/
│  ├─ ContentView.swift
│  ├─ AddCardView.swift
│  ├─ EditCardView.swift
│  ├─ CardDetailView.swift
│  └─ BarcodeScannerView.swift
├─ Models/
│  └─ Item.swift
├─ Validation/
│  └─ CardValidation.swift
├─ SeedData/
│  └─ DemoCardData.swift
├─ Utils/
│  └─ (placeholder per helper condivisi)
└─ README.md
```

## Note scanner

- Il simulatore iOS non supporta la fotocamera reale.
- Per test scanner usa un iPhone fisico.
- Deve essere presente `NSCameraUsageDescription` nel target app.

## Troubleshooting

### L'app non mostra più dati demo
- I dati demo vengono inseriti solo se il database è vuoto.
- Se hai già dati, il seed non viene rieseguito.

### Errori CoreData/SwiftData migration
- Se hai cambiato il model, può servire reinstallare app su device/simulatore.
- In sviluppo: elimina app dal device e rilancia da Xcode.

### Warning tastiera in console
- Alcuni log UIKit (es. `UIKeyboardLayoutStar`) sono warning interni iOS e spesso innocui.
