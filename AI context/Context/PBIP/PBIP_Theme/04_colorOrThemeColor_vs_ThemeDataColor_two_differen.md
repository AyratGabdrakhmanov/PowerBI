Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## `colorOrThemeColor` vs `ThemeDataColor` — two different ways to reference a color

The schema defines **two different types** for color properties, and not all properties
support both:

- **`colorOrThemeColor`** (string) — either a literal HEX (`"#RRGGBB"`) or one
  of the same 31 named root-field names. **Does NOT support** an index
  into `dataColors` with a brightness shift. Used, for example, by `border.color`,
  `background.color` in `commonCards`.
- **`themeDataColor`** (object) — `{"expr": {"ThemeDataColor": {"ColorId": N, "Percent": P}}}`,
  exactly the same structure as in `visual.json`. Available **only** where the property
  is typed as `fill` (not `color`!) — for example `fontColor`, `lineColor`, `fillColor`.
  Via `$/definitions/fill/oneOf[0]/properties/solid/properties/color/oneOf[1]`.

**Practical takeaway:** if you need to reference a specific palette color (`dataColors[N]`)
inside the theme, this is possible **only** for `fontColor`/`lineColor`/`fillColor`
(via `fill`), but **impossible** for `border.color`/`background.color`
(there only a literal HEX or one of the 31 fixed names, no indexing).

Example of a working palette reference inside a theme preset:
```json
"lineColor": {
  "solid": {
    "color": {
      "expr": { "ThemeDataColor": { "ColorId": 0, "Percent": -0.5 } }
    }
  }
}
```
`Percent` — brightness shift from -1 (black) to 1 (white); with `Percent: 0` the color is as is.
Power BI's exact darkening/lightening formula is not publicly documented; the linear
model `channel × (1 + Percent)` gives a close but not guaranteed pixel-exact
approximation — if you need 100% accuracy, it is better to insert the `ThemeDataColor` reference itself
(as above) rather than trying to compute the resulting HEX by hand.
