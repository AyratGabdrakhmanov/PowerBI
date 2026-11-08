Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## Table `fill` properties (`backColor`, `gridHorizontalColor`, `outlineColor`, `fontColor`) support `ThemeDataColor`

Addendum to the section "`colorOrThemeColor` vs `ThemeDataColor`" above: in all
table objects (`columnHeaders`, `grid`, `values`, `rowHeaders`,
`rowTotal`, `subTotals`) all color properties in the schema are typed as
`$ref: "#/definitions/fill"`, not `colorOrThemeColor` — i.e. *all* of them
(not only `fontColor`/`lineColor`/`fillColor`, as was noted earlier on
other visuals) support both a literal HEX (`{"solid":{"color":"#F3F3F3"}}`)
and a palette reference (`{"solid":{"color":{"expr":{"ThemeDataColor":{"ColorId":0,"Percent":-0.6}}}}}`).
Confirmed by checking against `reportThemeSchema-2.159.json` (`definitions/visual-pivotTable`).
