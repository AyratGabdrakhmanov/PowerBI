Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 37. Page background = the current reference SVG (all projects, user 2026-11-01)

Every page background is the newest reference SVG from `Reference\Maket\` (today `Agency_Background_1920x1080.svg`, generator
`Agency Demo\Agency_SVG_Layout.xlsx`: canvas 1920 × 1080, white header 90 px with the Agency logo, right panel 1620–1920 `#E9EEF7` with
the SAP B1 logo), never an old PNG / older SVG (`Background.svg`). Register the SVG as `Image` in `RegisteredResources` +
`report.json`, `page.json` → `objects.background` (scaling `Fit`, transparency 0). Fit the visuals to its zones: content
x 10–1610 below the header, panel visuals x 1650 / width 240; no logo image visuals (the SVG has them). Check: every
page background = the reference file (byte-equal), no visual crosses a zone, screenshot. Script (demo, one page):
`layout_Agency.py` logic in `ClientF_Context.md` (old PNG layout: header ~80, panel from x 1680 → content × 0.958).
