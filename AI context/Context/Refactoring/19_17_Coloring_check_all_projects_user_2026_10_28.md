Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 17. Coloring check (all projects, user 2026-10-28)

All report colors come from the standard palette, not from literals left over from old visuals (e.g. a converted
chiclet's white / light-blue look, step 3b).
- **Palette:** `_Measures` display folder `Color` — Sales Channels' 9 (`Light`, `Grey Lightest`, `Grey`, `Grey Dark`,
  `Blue Background`, `Blue Semi-Light`, `Blue Light`, `Blue Vivid`, `Blue Dark`) + `Teal` (`#389289`); reference ClientB
  `_Measures`. Missing in the model → add them first (hidden, folder `__Color`; never delete them — `CleanUnused.ps1` keeps
  the folder). In `_Measures` the folder is `_Color` (single `_`, step 27). **Reference file:** `Reference\DAX PRO Solutions\ColorMeasures.json` (11 measures incl. `Blue Logo` `#134591`,
  He / En captions; user 2026-10-30).
- **Button slicers / buttons / tabs:** selected `Teal`, default `Light`, hover `Blue Dark`, bound to the measures (fx),
  as ClientB `Page13` / `Page14`. Buttons with a theme fill and white text / icons (navigation) are not switched to `Light`
  blindly (text would vanish) — restyle fill + text together after the user agrees (ClientC 2026-10-28).
- **Check:** scan every `visual.json` / `page.json` for literal colors (`'#…'` in `Literal`) and list them per visual;
  each one → the matching Color measure, or kept on purpose (theme-equivalent, data colors of a chart series, CF rules —
  note why). Screenshots before / after per page.
