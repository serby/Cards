# Barcodes

The barcode types Card Barcodes reads and draws, how a code is drawn, what happens when one can't be, the brightness boost that helps a scanner read it, and how the camera focuses on and lights up a card to read its barcode.

### BAR-1: Keep cards with the common barcode types

As a card holder, I want the app to handle the barcodes loyalty and membership cards use, so that any of my cards works at the till.

- There are nine types, offered in this order in the Barcode Type menu: Code 128, Code 39, QR Code, EAN-8, EAN-13, Code 93, UPC-E, Aztec, PDF 417.
- The camera reads the same nine types (CARD-2). It reads no others, so a scan of ITF-14 or Data Matrix fills in nothing.
- A scanned code sets the barcode type to the type the camera read.
- Since 1.4: a photo or a file is read for the same nine types, and sets the type the same way (CARD-13). Other kinds it finds, such as Data Matrix, ITF-14 or Codabar, fill in nothing, and the form names them as kinds the app cannot show. The checksum and full ASCII forms of Code 39 and Code 93 read as Code 39 and Code 93.
- A card's type is stored by its name. A name the app doesn't know, from a newer build or a hand-edited export, reads as Code 128.
- QR Code and Aztec are drawn square. The other seven, PDF 417 among them, are drawn as a wide strip.

**Since:** 1.0
**Where:** `Cards/Core/Models/BarcodeType.swift`, `Cards/Scanner/CameraSession.swift` (`codeTypes`), `CardsTests/BarcodeTypeTests.swift`, `CardsTests/CardItemTests.swift`

### BAR-2: See a sharp barcode that scans

As a card holder, I want the barcode drawn large and clean, so that the till's scanner reads it first time.

- Codes are drawn on the device by RSBarcodes_Swift, through one helper, so the card screen, the arrival notification's attachment and the widget draw the same bars (1.3).
- On the card screen the code is drawn 400 points wide and a third as high for a strip, or 400 by 400 for a square code, at the screen's scale, then fitted to the width of the card.
- The bars sit on a white tile inside a grey, translucent frame, and the white stays white in dark mode (COL-3).
- The image attached to an arrival notification is the code on white with a 60 pixel quiet zone: 1,200 by 400 pixels for a strip, 600 by 600 for a square code. It does not show on the Lock Screen (ARR-1).
- The widget's image is one opaque image of the code on white with a quiet zone, so it stays scannable on tinted Home Screens (WID-6).

**Since:** 1.0
**Where:** `Cards/UI/Components/BarcodeImage.swift`, `Cards/UI/Components/BarcodeView.swift`, `Cards/UI/Components/CardWidgetView.swift`, `CardsTests/BarcodeViewTests.swift`

### BAR-3: Know when a code can't be drawn

As a card holder, I want to be told when a card's code can't be drawn as its barcode type, so that I can fix the type or the number.

- A code that is not valid for its type, such as letters in an EAN-13, is still saved with the card.
- The card screen shows "Failed to generate barcode" in dark ink where the barcode would be. The ink stays dark in dark mode (1.3).
- The widget shows "This code can't be drawn" (WID-5).
- The arrival notification still arrives, with its text and without the barcode image (ARR-1).
- The number is still shown under the barcode, so it can be typed in at the till.

**Since:** 1.0
**Where:** `Cards/UI/Components/BarcodeView.swift:20-28`, `Cards/UI/Components/CardWidgetView.swift:139-143`, `Cards/Core/Services/NotificationClient.swift:55-57`, `CardsTests/BarcodeViewTests.swift` (`barcodeOnWhiteAddsAQuietZone`)

### BAR-4: Brighten the screen while a card is open

As a card holder, I want the screen at full brightness while I show a card, so that the scanner reads it in any light.

- Brightness Boost is on by default. It is one setting, changed in Settings (SET-1) or with the sun button on a card, and kept on the device.
- With it on, opening a card fades the screen to full brightness over half a second, and VoiceOver announces "Screen brightness increased for better barcode visibility".
- Leaving the card fades the brightness back to where it was over 0.2 seconds.
- The sun button in the card's toolbar is filled and pink while the boost is on. Tapping it turns the setting on or off at once: on fades to full brightness and announces "Brightness boost on"; off fades back and announces "Brightness boost off" (1.1).
- With it off, opening a card leaves the brightness alone.
- The Settings caption reads "Boosts brightness when viewing card to improve scannability".

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/UI/Environment/ScreenBrightness.swift`, `Cards/Features/CardDetailScreen.swift`, `Cards/UI/Screens/SettingsListView.swift`
**Notes:** The brightness is put back when the card screen goes away, which includes opening Edit from it. The app doesn't put it back itself when it goes to the background with a card open.

### BAR-5: Scan a card held close to the camera

As a card holder, I want the camera to focus on a card held a few centimetres away, so that it reads the barcode without me hunting for the right distance.

- The scanner uses the first of these back cameras the device has: the Triple Camera, the Dual Wide Camera, the Dual Camera, then the Wide Camera. Without any of them it uses the device's default camera.
- A combined camera with an ultra-wide lens switches to it by itself when a card is closer than the main lens can focus, on iPhones that can focus that close (macro).
- The camera starts on the main lens, zoomed in just enough that a barcode 37 mm wide, the width of an EAN-13, fills the width of the camera view while the phone is still as far away as the main lens's minimum focus distance. This is Apple's rule from its AVCamBarcode sample. A lens that can focus that close gets no zoom, and the zoom never starts past 8x the main lens (CARD-2).
- Autofocus is continuous and kept to near subjects, and exposure is continuous, where the camera supports them.
- Only codes inside the camera view are read, not ones cropped off the top or bottom of the picture.

**Since:** 1.4
**Where:** `Cards/Scanner/CameraPlan.swift`, `Cards/Scanner/CameraSession.swift`, `Cards/Scanner/ScannerModel.swift`, `CardsTests/CameraPlanTests.swift`
**Notes:** The zoom comes from the main lens's minimum focus distance, not the combined camera's, which is the ultra-wide's macro distance on a Pro iPhone and would ask for no zoom. The simulator has no camera, so none of this shows there.

### BAR-6: Tap to focus on the barcode

As a card holder, I want to tap the camera view to focus on the barcode, so that the camera sharpens the card rather than what is behind it.

- Tapping the camera view focuses and sets the exposure at that point, once.
- A yellow square 72 points across shows where you tapped for a second, then fades. It shrinks onto the spot as it appears; with Reduce Motion on, it only fades in and out.
- When the picture changes a lot after a tap, such as when the card moves away, the camera goes back to continuous autofocus and exposure on the middle (BAR-5).
- After a read, tapping does nothing until the scanner view appears again (CARD-2).
- VoiceOver reads the camera view as "Barcode scanner", with the hint "Point the camera at a card's barcode to read it. Double-tap to focus on the middle." Double-tapping focuses on the middle of the view.

**Since:** 1.4
**Where:** `Cards/UI/Components/ScannerControlsView.swift`, `Cards/Scanner/ScannerModel.swift`, `Cards/Scanner/CameraSession.swift`, `CardsTests/CameraPlanTests.swift` (`pointOfInterestStaysInTheUnitSquare`)
**Notes:** In the Storybook, the ScannerControlsView story shows the square in fixed places and the ScannerPlaceholderView story shows it where you tap.

### BAR-7: Light up a card with the torch

As a card holder, I want to turn on the torch while scanning, so that the camera can read a barcode in a dim shop.

- A torch button sits in the bottom right corner of the camera view when the camera has a torch. A camera without one shows no button.
- Tapping it turns the torch on, and tapping it again turns it off. Off, it is a white torch on a dark, see-through circle; on, a black torch on a white circle.
- It is at least 44 points across and grows with the text size.
- VoiceOver reads it as "Torch", a switch that is "On" or "Off", with the hint "Lights up the card so the camera can read it in the dark".
- The torch goes off when a code is read, when the scanner leaves the screen and when the form closes.
- If the torch can't come on, such as when the phone is too hot, the button stays off.

**Since:** 1.4
**Where:** `Cards/UI/Components/ScannerControlsView.swift`, `Cards/Scanner/ScannerModel.swift`, `Cards/Scanner/CameraSession.swift`
