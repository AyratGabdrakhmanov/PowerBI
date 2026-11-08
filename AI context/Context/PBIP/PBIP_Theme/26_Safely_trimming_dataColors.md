Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## Safely trimming `dataColors`

A 480-color palette (see above) is often excessive. If you want to keep
only your "own" N base colors, **before trimming the array be sure to
check all `ThemeDataColor.ColorId` references** across the whole project:

```powershell
# All ColorIds used in visuals and in the theme itself
grep -rhoE '"ColorId": [0-9]+' "Model_v2.Report/definition/pages" | sort -u
grep -rhoE '"ColorId": [0-9]+' "Model_v2.Report/StaticResources/RegisteredResources/Classroom*.json" | sort -u
```

If an index **greater** than `(new array length - 1)` shows up anywhere,
it is a broken reference (it will point to a non-existent color). In practice this is exactly what
happened: we trimmed `dataColors` to 8 (`0-7`), and 4 waterfall visuals
(`increaseFill`/`decreaseFill` for the "decrease" category) referenced
`ColorId: 8` — we had to either restore the 9th color to the palette or deliberately
leave the reference broken (in this case Power BI does not raise an error when
opening the project — it just renders the "non-existent" color somehow;
the behavior is not documented).
