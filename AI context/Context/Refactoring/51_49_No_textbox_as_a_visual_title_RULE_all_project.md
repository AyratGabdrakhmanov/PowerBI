Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 49. No textbox as a visual title (⚠️ RULE, all projects, user 2026-11-05)

A static textbox placed on / right above one data visual as its heading → the visual's own title: `title.show = true`,
`title.text` = a `Title …` measure (He = the textbox text, En = translation, step 33), the textbox's style (size, bold,
underline, alignment; theme font color), the visual grows up to the textbox top, the textbox and its bookmark states are
deleted. Page headers (a textbox above the main table that already has a title) are not visual titles — they stay (or
become the page-title card). Check: script `textbox_titles` pairs (textbox above a visual with the title off) = 0.
ClientC `Sales NEW` 2026-11-05: 2 gauges on `דשבורד יעדים` (Targets dashboard) — `Title Targets - item groups` /
`Title Targets - areas`.
