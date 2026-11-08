Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 38. Pages hidden, navigation by buttons (all projects, user 2026-11-01)

Every page is `HiddenInViewMode` except the landing page (Power BI needs one visible page; `pages.json` `landingPageName`);
viewers move only with the navigation buttons (`actionButton` → `PageNavigation`) on every main page. Check: script — every
navigation button targets an existing page, every main page reachable from the landing page, no page left visible but the
landing one. **Navigation design — two variants** (user 2026-11-01, choice open): **A** buttons stacked in the right panel
(today's layout); **B tabs** — a 55 px tab strip under the header (`Agency_Background_Tabs_1920x1080.svg` = the Agency SVG +
`<rect x="0" y="90" width="1620" height="55" fill="#FFFFFF" />` + a `#E0DED9` line at y 144.5), the page buttons as one row
of tabs (RTL: first page right-most, gap 6), the panel keeps only slicers, content below the strip (× 0.94 vertically).
Reference demo: ClientF Sales v2 `Firstpage` (A) / `FirstpageTabs` (B), 2026-11-01.
