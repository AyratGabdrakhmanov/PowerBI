Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## `GreyShadeTabActive` / `GreyShadeTabInactive` — tab presets (Collector Assignment, 2026-10-16)

Presets for the horizontal tab menu of the `Tabs *` pages (see "Tab-navigation pages" in
`PBIP_Recipes.md`). Named with "Grey" like the existing presets (user: keep them uniform).
- Built as a **full copy** of `GreyShadeActive` / `GreyShadeInactive` (every state of
  `fill`/`outline`/`text`/`padding` — the "whole array" inheritance rule above), plus what
  the tab buttons had locally:
  - both: `shape` `tileShape: tabRoundTopCorners`, `roundEdge: 0`, **`tabRoundCornerTop: 35`** — Format
    pane "Rounded top corners" **35 %** (user 2026-10-16: "rounded corners = 35% as default"; the user had
    set it locally on the 5 tabs of `Tabs DPD By Date` — those locals removed, the style covers them).
    ⚠️ Not `roundEdge` ("Round edges") — that stays 0. The
    **first tab does not use these two styles and gets no rounding** — see the first-tab styles
    below; `text` `disabled` state;
  - Active: `outline.show: false`, `fill` default `transparency: 0`, shape `shadow`
    (`custom`, angle 270, distance 10, blur 0, transparency 0, `ThemeDataColor` 0 / −0.3) —
    draws the bar under the active tab;
  - Inactive: `fontColor` `ThemeDataColor` 1 / **0.2**; `fill` default **fixed `#FDFCFA`**
    (= the constant measure `Measure[Light]` that the tabs used before — user: fixed color).
- **Font:** Calibri in every state (user: "Calibri always"); size **14** in all states of
  all four `GreyShade*` presets and in `actionButton.*` `selected` (was 13 / 12 / 11 disabled).
  The global `*.*` was not touched. 87 buttons that had `fontSize 13D` locally → `14D`.
- After a preset is assigned, the locals it covers were removed from `visual.json` (shape,
  outline, shadow, glow, icon, fontColor, the `Light` fill, the disabled Arial Black entry).
  Left local: the text measure (`Page Name …`), `navigationSection`, container settings.
- **Border / shadow check (2026-10-16, user: "check border / shadow applicable to styles"):**
  the visible bar under the active tab is the **button** `shadow` (object level) of
  `GreyShadeTabActive` — already in the preset. The **container** `dropShadow` that the 30
  non-first tab visuals had locally (`Custom`, angle 90, blur 3, transparency 86) was dead: `show`
  was never `true` (inherits `*.*` `dropShadow.show: false`) → removed from those 30. Container
  `border` — no locals, `actionButton.*` `border.show: false` covers it. ⚠️ **The same cleanup was
  wrongly applied to the first tab too** (its `dropShadow` `show: false` / `background` `show:
  false` / `padding.top: 0` are the user's own design) — restored from the backup on 2026-10-16
  and kept local on the first tab (see the first-tab styles below). Leftovers identical on all
  tabs, not touched: `title` (`show: false`, text `Page5`), `subTitle`, `spacing`. Backup
  `ClientA\BackUp\2026-10-16_TabsDesign_CollectorAssignment` (state before both tab edits).
- **Tooltips:** off by style — `actionButton.*` `visualLink.showDefaultTooltip: false`,
  `*.*` `visualTooltip.show: false`. Do **not** add `visualLink` to a preset just to repeat
  it — the preset would then have to carry the whole `visualLink` array (`show`, `type`…).
  Local `tooltip` / `enabledTooltip` / `disabledTooltip` / `showDefaultTooltip` were removed
  from all buttons **except `Drillthrough` ones** (user: never touch drillthrough buttons;
  14 kept byte-identical) — 87 properties in 67 buttons.
