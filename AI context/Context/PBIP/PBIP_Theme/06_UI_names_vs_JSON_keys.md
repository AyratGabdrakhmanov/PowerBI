Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## UI names vs JSON keys

**Button / tab shape corners (`actionButton` `shape`, checked in `reportThemeSchema-2.159.json`,
2026-10-16)** — each Format pane setting is its own key, and they depend on `tileShape`:

| Format pane (Shape) | JSON key | Applies to `tileShape` |
|---|---|---|
| Rounded top corners (%) | `tabRoundCornerTop` | `tabRoundTopCorners` (Tab: rounded top corners) |
| Rounded top right corner (%) | `tabRoundCornerTopRight` | `tabRoundCorner` (Tab: rounded corner) — our **active first tab** |
| Rounded bottom corners | `tabRoundCornerBottom` | tab shapes with bottom corners |
| Rounded corners | `rectangleRoundedCurve` | rounded rectangle |
| Round edges | `roundEdge` | generic — **not** the tab corner settings |

**Tab presets (`actionButton`, in `Reference\Maket\ThemeWarm.json` since 2026-11-04):** `GreyShadeTabActive` /
`GreyShadeTabInactive` (rounded top corners, inactive with outline); `GreyShadeTabFirstActive` = rounded top right
corner, **no outline** (no vertical line on the left, next to the side panel), top line drawn by a shadow (angle 270);
`GreyShadeTabFirstInactive` = a copy of `GreyShadeTabInactive` (user 2026-11-04). A button outline is all four sides
or none - an inactive first tab without the left line would also lose its bottom line, which separates it from the
page (tried and rejected). **The active tab must have the highest `z` of the tabs on its page**, otherwise the
neighbour's outline is drawn over its rounded corner (fixed on 12 Collector Assignment pages 2026-11-04).

The value is an integer; the Format pane shows the tab corner ones in %. Found the hard way: 35 was
first written to `roundEdge` instead of `tabRoundCornerTop` (2026-10-16). Before writing a shape
setting, look the key up here / in the theme schema, or read a visual where the user set it in
Desktop.

The Power BI Desktop Format pane **renames** some properties in the interface
relative to their actual name in JSON. Example: what in the schema and in `visual.json`
is called `outline` (for `actionButton`) is labeled **"Border"** in the Format pane.
A separate JSON property `border` at the level of the visual itself (`objects`) does not exist —
`border` exists only at the container level (`visualContainerObjects.border`, the frame
around the whole visual, not the outline of the button itself).
