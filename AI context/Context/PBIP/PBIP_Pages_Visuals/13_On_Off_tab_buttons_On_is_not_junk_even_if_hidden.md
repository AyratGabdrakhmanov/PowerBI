Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️ On/Off tab buttons — "On" is not junk, even if hidden and it "does nothing" (ClientB, 2026-10-13)

A typical tab pattern on a page: in one spot (same `x/y`,
size, label) there are two buttons — `Button<View>Off` (normal, clickable) and
`Button<View>On` (highlighted — the indicator of the current view). The view's
bookmark shows `…On` and hides the `…Off` of its pair; the other bookmarks do
the opposite. Therefore:
- **Do not delete `…On`**, even if it has `isHidden: true` in the file and its link is
  broken: in its own view's state it is visible; without it there is a hole
  in place of the tab. Check: which bookmarks show it (`visualContainers.<name>` without
  `display.mode: hidden`) and hide its `…Off` pair.
- **The `…On` link = the link of its `…Off`** (the bookmark of its own view) — clicking the
  current tab simply re-applies it. On ClientB `Page2`, of 6 tabs, 4
  `…On` buttons led to a non-existent bookmark and 2 to someone else's view (clicking the
  current tab "Document number" switched to "Agent"); it was already like this in the
  8.07 archive — meaning that when the tabs were copied, the `…On` links were not
  reconfigured. To find: compare the link of each `…On` with the link of its `…Off`.
- A button with the same label on another page that leads to a bookmark of another
  page (`activeSection` ≠ the button's page) is a sign of copied
  navigation; the bookmark takes the user away from the page. Do not fix silently —
  ask whether it is intended (ClientB: «חזור לברירת מחדל» — "Reset to default" on
  3 pages, question 14 to Guy).
- **Reset buttons ("Reset to default") reset the slicers of their OWN page —
  via the built-in action Clear all slicers, NOT a bookmark** (user decision
  2026-10-14, ClientB). In `visual.json`:
  `visualContainerObjects.visualLink[0].properties.type = 'ClearAllSlicers'`, no
  `bookmark` property. Works on any page without per-page setup and does not break
  when pages are copied/deleted (bookmark-based resets did: they kept pointing to the
  source page). Side effect: it clears ALL slicers of the page, incl. date ranges,
  slicers with a default selection and field-parameter button slicers
  (`advancedSlicerVisual`) — check that before adding it to such a page.
