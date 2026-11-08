Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## `visualStyles` and Style Presets

```json
"visualStyles": {
  "*": { "*": { /* global settings for ALL visuals */ } },
  "actionButton": {
    "*": { /* default style for all buttons */ },
    "GreyShade": { /* named preset — custom Style preset */ }
  }
}
```

- `visualStyles.*.*` — the base for absolutely all visuals in the report.
  **Title color (Collector Assignment theme `ThemeWarm…json`, 2026-10-24, user "make title black — apply to
  theme"):** every `title` array in `visualStyles` (`*.*` and the presets, 9 arrays — by the whole-array rule a
  preset's `title` replaces the `*` one) has `fontColor` `#070f25` (= `foreground`, "Theme color 1", what the
  local titles use). Without it a title with no local color shows Power BI's default grey. Same file in the thin
  Scorecard report — edit both copies.
- `visualStyles.<visualType>.*` — the base for a specific visual type (overrides
  the global `*`).
- `visualStyles.<visualType>.<PresetName>` — a **named preset**: any key
  other than `*`. Appears in Power BI Desktop in Format pane → **Style presets** →
  drop-down list, next to the product's built-in presets (for `actionButton`
  these are `Default`/`Outline`/`Transparent`/`Icon & Text`).

**Important:** both `*` and a named preset use **one and the same** schema definition
(`visual-<type>` = `commonCards` + type-specific fields). So a preset can
contain not only the visual's "inner" properties (`fill`, `outline`, `text`, `shape`,
`icon` — what you see in the Format pane under the visual itself), but also **container**
ones (`border`, `background`, `padding`, `title`, `subTitle`, `visualLink`, `spacing`,
etc. — what relates to the frame/backdrop around the visual). If you don't account for this,
the preset will "fix" only the inner look, while the border/background/padding will remain from the global
`*` — and the visual will **differ slightly** from the reference one, which had these properties
explicitly turned off locally.
