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

## 2. Text never sits on a card colour

A card can be any colour, so no colour can be relied on to keep text readable. Text on a card face or a widget sits on a white panel (`CardPanel.fill`) in dark ink: `CardPanel.ink`, or `CardPanel.secondaryInk` for supporting text such as a place or a date.

- Panels stay white in dark mode, like the barcode.
- Marks that are not text, such as the colour picker's tick, may go straight on a colour, in `CardInk.best(on:)`, the ink that stands out more.
- Tinted and clear Home Screens draw a widget in one tint, where white panels would hide the text. There the panels drop their fill and the text takes the tint (`widgetRenderingMode`).

## 3. Card colours

- **The palette** (`CardColor.allCases`): 23 colours, by hue and then the neutrals. The picker shows six to a row with the custom colour well last, so the palette size plus one must stay a multiple of six; a test checks.
- **Custom colours:** any sRGB colour from the system colour picker, stored as `#RRGGBB` in the card's existing colour field. Builds from before custom colours show them as Default.
- **Contrast:** every palette colour keeps its best ink at WCAG AA (4.5:1), and list rows keep the system label at AA over the wash of any colour, palette or custom (checked over a sweep of 216 colours). If a test fails, change the colour, never the threshold.
- **Adding a palette colour:** a case, a raw value, a hex value and a display name. Raw values are stored in every card, so existing ones never change.

## 4. Gradients

Card faces, the widget's background and the picker's swatches fill with the card colour's system gradient (`Color.gradient`, through `cardFill` and `widgetFill`), so a card looks the same wherever it appears. List rows keep a flat, faint wash, and nothing else gets a gradient. Because text sits on panels, a gradient never changes how readable it is.

## 5. Everything else

- **Accent:** the brand pink `Color.accent` is for controls and links, and meets AA on the system background in both appearances.
- **Quiet actions** beneath content, such as "Add current location" on a card: footnote size, secondary colour, borderless.
- **Shadows** belong to the card face only.
- **Words:** British English in everything the user reads ("colour"), Swift's spelling in identifiers (`color`).
