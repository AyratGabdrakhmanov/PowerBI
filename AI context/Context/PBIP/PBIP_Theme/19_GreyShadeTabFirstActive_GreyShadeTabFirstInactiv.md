Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## `GreyShadeTabFirstActive` / `GreyShadeTabFirstInactive` — styles of the FIRST tab (2026-10-16)

⚠️ **The first tab (Overview) of every `Tabs *` page is different from the other tabs** (user's design
made on `Tabs Overview`): its own corner shape and geometry. Full description and the comparison table —
`PBIP_Recipes.md`, "The first tab (Overview) is different". Why separate styles: when the tab
presets got `roundEdge: 35` ("35% as default", user), the first tab — which only had a local
`tileShape: tabRoundCorner` and inherited the rest — changed with them and no longer matched the design
(user: "it's broken").
- Built as **full copies** of `GreyShadeTabActive` / `GreyShadeTabInactive` (every state of every
  array — "all or nothing" rule); the **only** difference is `shape`:
  `[{"$id": "default", "roundEdge": 0, "tileShape": "tabRoundCorner", "tabRoundCornerTopRight": 35}]`.
  The first tab is different: its corner setting in the Format pane is **"Rounded top right corner"**
  (`tabRoundCornerTopRight`, shape `tabRoundCorner`) = **35 %** (user 2026-10-16), not "Rounded top
  corners" (`tabRoundCornerTop`, the other tabs). Do not copy the other tabs' key here. `GreyShadeTabFirstActive` only on `Tabs Overview`
  (`a98d284b46eac8ae4cc7`), `GreyShadeTabFirstInactive` on the first tab of the other five pages.
- The first tab's local `shape` was removed (the style covers it). **Kept local** (not moved into the
  styles): container `dropShadow`, `background`, `padding.top 0` — a preset merges the object-level and
  container-level `padding`/`background`/`shadow` under one key (see "Key collision" above), so only the
  object-level shape goes into the style. Plus the usual locals: text measure, `navigationSection`.
- Not in the master `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\Maket\ThemeWarm.json` (it has no tab presets at all).
- Check done through files: the styles equal the tab styles except `shape`; the first tab equals the
  design backup except the style name, the removed local `shape`, and `ColorId 5→7` (the same teal after
  the palette reorder; irrelevant while `background.show: false`).
