# Cards visual style

The rules every screen, widget and story follows. Rule 5 in [DEVELOPMENT.md](DEVELOPMENT.md) points here, and a screen that breaks one of these has a bug.

## 1. Corners nest

A rounded shape inside another takes the outer radius minus the gap between them:

```
inner radius = outer radius − inset
```

The curves then run parallel and the shapes read as one object. A radius picked by eye looks pinched (too large) or boxy (too small) against the shape around it, so never choose one; derive it.

- **Card face:** `CardGeometry` holds the chain. The card is `cornerRadius` (28). Its panels sit `inset` (12) in, so they are `panelCornerRadius` (16). The barcode's frame is `barcodeFrame` (6) thick, so the white inside it is `barcodeCornerRadius` (10). `CardGeometryTests` checks each step.
- **Widgets:** WidgetKit owns the widget's corner radius and margins, which differ between devices, so panels use `ContainerRelativeShape()`, which does the subtraction itself. Storybook's widget frame sets `.containerShape(.rect(cornerRadius: 22))` so stories match.
- **Panels in a column line up:** the same width, the same radius, `inset` apart. The text panels and the barcode's frame on a card face are one column.
- **A new nested shape** gets a constant in `CardGeometry`, derived from the shape it sits in, and a line in the test.

## 2. Text on a card colour is always readable

A card can be any colour, so text on one is readable by construction, in one of two ways:

- **On a white panel**, in dark ink: `CardPanel.ink`, or `CardPanel.secondaryInk` for supporting text such as a place or a date. Card faces and widgets put all their text on panels, and a list row's distance sits on a white pill. Panels stay white in dark mode, like the barcode.
- **Straight on the colour**, in the colour's `ink` (white or near-black, whichever stands out more), over `readableBackground` and its `gradient`. Those guarantee WCAG AA for any colour: a colour so mid-toned that neither ink reaches 4.5:1 is moved away from the ink, towards black or white, only as far as it takes. Every palette colour already passes, so the palette is never moved. A list row's card name and the picker's tick sit on the colour this way.

Never put text on a colour's raw `background`. Tinted and clear Home Screens draw a widget in one tint, where white panels would hide the text, so there the panels drop their fill and the text takes the tint (`widgetRenderingMode`).

## 3. Card colours

- **The palette** (`CardColor.allCases`): 23 colours, by hue and then the neutrals. The picker shows six to a row with the custom colour well last, so the palette size plus one must stay a multiple of six; a test checks.
- **Custom colours:** any sRGB colour from the system colour picker, stored as `#RRGGBB` in the card's existing colour field. Builds from before custom colours show them as Default.
- **Full colour:** cards show their colour at full strength wherever they appear, in the list as on the card screen. Readability comes from the rules in section 2, never from fading the colour.
- **Contrast:** every palette colour's ink meets WCAG AA (4.5:1) on it unmoved, and the ink meets AA at both ends of the gradient for any colour, palette or custom (checked over a sweep of 216 colours and the mid greys). If a test fails, change the colour, never the threshold.
- **Adding a palette colour:** a case, a raw value, a hex value and a display name. Raw values are stored in every card, so existing ones never change.

## 4. Gradients

Card faces, list rows, the widget's background and the picker's swatches all fill with the card's `gradient`, so a card looks the same wherever it appears. It is lighter at the top, as if lit from above, and only ever moves away from the ink: a dark colour darkens towards the bottom, and a light colour lightens towards the top. Text on it therefore stays at least as readable as on `readableBackground` all the way down. Nothing else gets a gradient.

## 5. Everything else

- **Accent:** the brand pink `Color.accent` is for controls and links, and meets AA on the system background in both appearances.
- **Quiet actions** beneath content, such as "Add current location" on a card: footnote size, secondary colour, borderless.
- **Shadows** belong to the card face only.
- **Words:** British English in everything the user reads ("colour"), Swift's spelling in identifiers (`color`).
