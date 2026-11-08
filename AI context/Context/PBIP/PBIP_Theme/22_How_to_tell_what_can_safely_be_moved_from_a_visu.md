Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## How to tell what can safely be moved from a visual to a preset

Practical algorithm:
1. Walk the whole `visual.json` and find all `properties` that are **not empty**
2. For each one decide: is it a *shared style* (suitable for moving into a preset — font
   size, color, corner rounding, line thickness, link action type) or
   *unique data of a specific instance* (button text, `navigationSection` —
   target page, values bound to measures)
3. Copy the shared ones into `visualStyles.<type>.<PresetName>` in the theme (taking into account
   the `colorOrThemeColor`/`themeDataColor` limitations above)
4. After moving — remove from `visual.json` what now duplicates the preset
   (otherwise the local value will mask the preset, and when the preset is later changed
   the visual will "not pick up" the edit)
