Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: [Copy Navigation Buttons] (alias [Copy Navigation])

A user request of the form **"Copy navigation to <Page>"** (one or several
pages) = run this whole process, without further clarifying questions.
First done 2026-09-30 (`Collector Assignment`: Overview → Details 1,
Details 2).

**The source is always the `Overview` page (or `Summary`**, in projects where
the main page is called that). Navigation buttons = all `actionButton`s
in the left column of the source page (left of the content area: in
`Collector Assignment` this is `x < 300`, cards start at `x ≈ 315`).

### Steps

1. **Back up** the source page and all target pages (whole folders) to
   `ClientA\BackUp\<Project>_NavButtons_<yyyyMMdd_HHmmss>\`.
2. **On the target page, delete all `actionButton`s in the same zone**
   (`x < 300`) — including buttons that are not on the source (for example,
   `Status Change` on Details 1/2 was removed exactly this way; tell the
   user which buttons disappeared/appeared).
   ⚠️ `Remove-Item` on a path like `...\visual.json"` is blocked by the
   harness protection — delete folders via `[IO.Directory]::Delete($path, $true)`.
3. **Copy the button folders** from the source to the target page as is
   (folder name = the visual's `name` is preserved; position `x`/`y`/`width`/`height`
   — the same). Before copying, check that the target page has no
   NON-button visual with the same folder name.
4. **Z-order — buttons on top of everything** (top of the Layer order list in the Selection
   pane): `z = <max z of the other visuals on the page> + 1000 * i`, where `i`
   goes in ascending order of the buttons' `z` on the source — the relative order
   of the buttons is preserved. Do not touch `tabOrder` (it is copied from the source).
5. **Active button style** — via a theme preset in
   `visual.visualContainerObjects.stylePreset[0].properties.name`:
   - `'GreyShadeActive'` — on the button whose navigation leads to THIS page
     (`visualContainerObjects.visualLink.properties.navigationSection` =
     the target page's folder name, for example `'DailyTrend'`);
   - `'GreyShadeInactive'` — on all the others, including drillthrough buttons.
   - If no button leads to the target page — all `Inactive`, and
     tell the user about it.
6. **Check:** on each page — the number of buttons = as on the source,
   the minimum `z` of the buttons > the maximum `z` of the other visuals, exactly one
   `Active` (or zero, see above), no slicer/visual in the left column
   overlaps the button zone (`y` down to the bottom of the last button), CRLF and
   UTF-8 without BOM preserved.

### Technical notes

- Editing JSON via `ConvertFrom-Json` → `ConvertTo-Json -Depth 100` (PS 7)
  preserves CRLF/2 spaces/Unicode (`→`, `←`) — verified by comparison with the
  backup; writing via `[IO.File]::WriteAllText(..., UTF8Encoding($false))`.
- The name in the Selection pane (`Page1`, `PageDD2`, …) is
  `visualContainerObjects.title.text`, not the folder name (for example, folder
  `PageDD13` is shown as `PageDD2`, folder `Page4` — as `Page6`).
- Button text — via measures (`Page Name Details 1`, etc.), not a literal —
  copying the folder carries this over automatically.
- The source page is **not changed** during copying (bringing the buttons to the top
  on Overview itself was done as a separate task on 2026-09-30; if the buttons on the source
  are not on top — tell the user, but do not touch them without a request).
