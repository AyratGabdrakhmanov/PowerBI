Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️⚠️ Inheritance inside `visualStyles` — by the WHOLE array, not by `$id`

**This is the most important and least obvious finding of the whole session.** If a preset (or
`"*"`) defines a property such as `fill`/`outline`/`text`, this array is **not
merged** by `$id` with the same property at the level above (for example
`visualStyles.<type>.*`). Instead the "all or nothing" rule applies:

> If a named preset mentions the `fill` key at all (even with a single
> entry `$id: "default"`), the entire `fill` array from the base `"*"` is **completely ignored**
> for this preset. The `hover`/`selected` states that are not
> in the preset are not inherited from the base — they fall back to the **raw built-in
> Power BI default**, not to what is set in `"*"`.

**How we ran into this:** we moved `fill.hover`/`fill.selected` and
`text.hover`/`text.selected` up into `visualStyles.actionButton.*`, leaving only
`$id: "default"` in the `GreyShade`/`GreyShadeInactive` presets (thinking that
the missing states would be pulled in from the base). Result:
- `fill` on hover became **dark red** — it turned out to be `dataColors[0]`
  (our first base color!). Apparently an unspecified color in a fill property
  is taken by Power BI from `dataColors[0]` by default, rather than left transparent.
- The font on `selected` ("press") reverted to **Segoe UI** — because
  `fontFamily` for the `selected` state existed only in the base, and since the preset
  defines `text` at all, the base for `text` no longer applies at all.

**Practical rule:** if a preset mentions `fill`/`outline`/
`text`/`shape`/`icon` (or any other property with states) **at all**, it must
contain **all the needed states itself, in full**, rather than rely on
partial inheritance from above. It is safe to move up into the base only those properties
that the preset **does not mention at all** (in our case — `border`, `background`,
`padding`, `visualLink`, `shape`, `icon`, `title` — they are single-entry, without
competing `$id`s, and the presets did not override them).

**Pressed state = normal state (ThemeWarm, 2026-11-02):** `actionButton.*` `text.selected`
had `fontSize 12`, `rightMargin 0`, so the text jumped on press (normal = base-theme margins 12 / 12 / 6 / 8, 10.5).
Now `*` sets the margins 12 / 12 / 6 / 8 explicitly on `default` / `hover` / `selected` and `selected` has no own size;
`GreyShadeActive` / `GreyShadeInactive` `selected` = their `default` (size 13, margins 0, same bold). Hover stays bold
by design. In a visual, set measure-driven text / fill on every state (`default`, `hover`, `selected`): a state set
only as `default` falls back to the theme on hover / press (a button went blank on hover).

**Settings waterfall (⚠️ RULE, user 2026-11-02):** put every formatting setting on the highest level that does not
contradict another setting: theme `*` → visual type (all slicers, all tables, …) → style preset of a visual type → one
object in the report. Per-object settings only for what cannot live higher (measure-driven text / colors, sizes,
positions, a single visual's exception); when a setting moves up, remove the per-visual override, or it keeps winning.
Applied 2026-11-02: titles of `slicer`, `advancedSlicerVisual`, `pivotTable`, `tableEx` = deep blue `#134591` (= logo
blue, measure `[Blue Logo]`; other types keep black from `*`); `actionButton.*` icon `hover` = `#000000`.
**Exception — tooltip-page padding (⚠️ RULE, user 2026-11-03):** the padding of a tooltip-page text button (e.g. 15)
stays local on that button (`visualContainerObjects.padding`), never in the theme `actionButton` — small report buttons
(26–39 px high) would lose their text to 15 + 15 px padding.
