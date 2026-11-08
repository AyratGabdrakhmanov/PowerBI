Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: add a new KPI card (cardVisual + time-intelligence measures)

The established project pattern for cards on the `CardWithReference` preset
(see above): the card references **2 measures** (`X Change Month`, `X Change Year`),
each a one-line call to `Collection.FormatRefLabel` (see above), plus the
card itself (`visual.json`).

### Measures (in `Measure.tmdl`)

For a base measure `[X]` only these are created:
- `X Change Month` = `Collection.FormatRefLabel ( "Row3", "Month", [X], <fixTotal> )`
- `X Change Year` = `Collection.FormatRefLabel ( "Row3", "Year", [X], <fixTotal> )`

For an `X` that is already a percentage — `rowType = "Row2"` instead of `"Row3"`.

`fixTotal` — the total space budget before `"Δ: "` in the `Row3` variant; the project
uses different values on different cards (`11`, `18`, `19`) —
chosen empirically so that the card's Month and Year lines visually
align (the value depends on the typical width of the specific measure's numbers).

### Card (`visual.json`)

Mandatory minimum of local content (the rest comes from the theme,
`CardWithReference`):
- `query.projections` — binding to the base measure `[X]`
- `objects.referenceLabel.value` → measure `X Change Month`
- `objects.referenceLabelTitle` → `titleContentType: 'custom'`,
  `titleText: 'Prev. Month:'` for Month, `'Prev. Year:'` for Year —
  ⚠️ in the Year variant, after the colon, the existing cards have NOT
  regular spaces but a sequence of special characters `U+2006` + four
  `U+2008` + one regular `U+0020` (visual width alignment with `Prev. Month:`) —
  when copying the node from an existing card (Edit/JSON,
  not typing the text manually) this is preserved automatically; if you type the value
  anew by hand, be sure to compare byte-by-byte with any existing
  card (`node -e` + `Buffer`/`codePointAt`), otherwise you will get regular
  ASCII spaces and the alignment will break (found and fixed 2026-09-05)
- `objects.cardCalloutArea.backgroundFillColor` → measure `Light`
- `objects.divider.dividerColor` → measure `Grey` (not via `ThemeDataColor` —
  a theme cannot reference measures, see above)
- `objects.border.show: false`
- ⚠️ `objects.padding` (`paddingUniform: 0`, `paddingIndividual: false`) —
  critical for correct formatting, see above
- `objects.spacing.verticalSpacing: 2`
- `visualContainerObjects.title` → text + `background` via measure `Light`
- `visualContainerObjects.subTitle` → text + `fontColor` via measure
  `Grey Dark`
- `visualContainerObjects.divider.color` → measure `Grey`
- `visualContainerObjects.stylePreset.name: 'CardWithReference'`

### Positioning

Place the new card in a row with the existing ones: width `215`, gap between
cards `10` (so the X step = `225`), height `130`, `y: 15`. Before
adding — check which coordinates are occupied (`grep`/`awk` over `x`/`y`/`width`
of all `visual.json` files on the page), rather than assuming the spot is "probably"
free.
