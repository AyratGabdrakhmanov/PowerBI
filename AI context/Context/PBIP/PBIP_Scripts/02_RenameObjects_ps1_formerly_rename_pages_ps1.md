Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `RenameObjects.ps1` (formerly `rename_pages.ps1`)
File: [`ClientA\_Documentation\RenameObjects.ps1`](<../../../Scripts/RenameObjects.ps1>).
Two parts in one script:

⚠️ **Fixed in `2026-10-14.1` — bookmark visual renames are now PER PAGE.** Up to
`2026-10-13.1` Part 3 merged the visual renames of all pages into ONE map (last page
wins) and applied it to every bookmark. Visual names are unique only within a page
(`slicer3` exists on many pages), so slicer states / show-hide flags in bookmarks
landed on the wrong visuals. ClientB 2026-10-13: 79 of 150 slicer states on 6 pages,
plus page default visibility flipped after a broken bookmark was applied and saved,
plus the clean-up deleted "hidden visuals no bookmark shows" judged from broken
bookmarks. Now: page names — one pass over the whole file; visual names — only
inside `sections.<Page>` with that page's map, `targetVisualNames` with the
`activeSection` map. Test (2026-10-14, 173 slicers renamed on 17 pages): old
version 174/313 states wrong, fixed version 0 new errors.
**`2026-10-14.2` — visual names are unique across the WHOLE report** (user
decision): one name registry for all pages, pages processed in tab order, so the
numbering is stable on repeat runs (tested: second run renames 0). ClientB: 263 renamed,
0 duplicates of 346.
**After every run — check (static, no clicking in Desktop):**
`python "ClientA\_Documentation\Scripts\CheckBookmarks.py" "<...>.Report\definition" [--ref "<known-good>.Report\definition"]`
— A structure (pages/visuals/targets exist), B buttons (bookmark exists and stays
on the button's page), C slicer states vs slicer fields, D shown/hidden vs a
reference report, E dead items (uncalled bookmarks, hidden visuals no bookmark
shows). Expect A, B, C = 0. (`CheckBookmarkSlicers.py` = check C alone.)
⚠️ It has no argument parsing: the first argument is always the folder (`--help` included) and a wrong
or empty folder prints `A … E: 0` — all zeros prove nothing unless the path is right (ClientB 2026-10-18).

**Part 1 — pages.** Renames page folders based on `displayName` from
`page.json` (sanitizing the name — see below), syncs `name` and updates
`pages.json` (`pageOrder`/`activePageName`/`landingPageName`). On a
`displayName` collision between two different pages, the folder already sitting on the correct name
keeps it; the "newcomer" gets a numeric suffix (not the other way round). After
renaming, it goes through **all** `visual.json` files of **all** pages and fixes
`navigationSection`/`section`/`drillthroughSection` on navigation buttons,
tooltips and Drillthrough buttons (see the separate section below — this was a real
bug that was found, previously not tracked at all; `drillthroughSection`
was added later, 2026-09-15).

**Part 1b — page display settings.** After renaming, it goes through
the `page.json` of **every** page (not only renamed ones) and brings
two fields to the standard:
- `displayOption: "FitToPage"` (at the top level of `page.json`)
- `objects.displayArea[0].properties.verticalAlignment` = `'Middle'`
  (vertical centering of the page content) — if `objects` or
  `displayArea` are missing, they are created from scratch (the only existing
  form in the project is an array of one element with a single property
  `verticalAlignment`, see `Overview/page.json` as a model).

This is a project convention (not a diagnosed bug) — it is checked and fixed
on every script run, regardless of renaming.

⚠️ **`displayArea.verticalAlignment` is now also set in the theme**
(`visualStyles.page.*.displayArea: [{ "verticalAlignment": "Middle" }]` in
`Classroom*.json`, see "`visualStyles` and Style Presets" below) — confirmed
against the official Fluent2 base theme (`Fluent2-CY26SU07.json`), where `page.*`
uses exactly this syntax. This means vertical centering is now
set GLOBALLY by default for all pages via the theme, and the check in
`rename_pages.ps1` Part 1b is now a safety net in case of a local
override in a specific `page.json` (which masks the theme), not the only
source of this setting.
**Since `RenameObjects.ps1` `2026-10-15.1` (ClientB, user rule "vertical alignment Middle
ALWAYS")** Part 1b also checks the custom theme (`report.json` → `themeCollection.customTheme`,
`RegisteredResources`): if `visualStyles` has no `page` style, it inserts
`"page": { "*": { "displayArea": [ { "verticalAlignment": "Middle" } ] } }` as text after
`"visualStyles": {` (the rest of the theme keeps its formatting); an existing `page` style
without Middle → WARN only. ClientB's `Classroom` theme had no `page` style (new pages would
start at Top) — test on a copy: +9 lines in the theme, nothing else in it changed.
`displayOption` (`"FitToPage"`) is **not themeable**: in the theme schema
(`reportThemeSchema-2.159.json`) and in the Fluent2 base theme this property does not exist
at all for any style — it is a purely structural `page.json` setting (like
`height`/`width`), not part of the `objects`/`visualStyles` system. It stays
only in the script.

**Part 2 — visuals.** Renames visual folders **within each page**.
Name source priority:
1. `visualContainerObjects.title.text` (the same field that controls the name in
   the Selection pane — see below) — gives meaningful names such as `Page1`,
   `SalesSummary`
2. `objects.header.text` — the second-priority source, for visuals without
   a container `title` (typical for slicers — they usually only have
   their own header `header.text` set, for example `"Days Past Due
   Changed Manually"`, while `visualContainerObjects.title` is empty)
3. Fallback to `visual.visualType` (`shape`, `slicer`, ...), if neither `title.text`
   nor `header.text` is set or they are not text literals

**Name sanitization (`Get-SafeName`).** The extracted text (from `title`,
`header` or `visualType`) is reduced to **ASCII letters and digits only**
(`-replace '[^A-Za-z0-9]', ''`) — spaces, any special characters
(`#`, `%`, `.`, `-`, `_`, `()`, `/` etc.) **and any non-ASCII characters**
(Hebrew, Cyrillic etc.) are removed. The reason is broader than just "special characters are unreliable":
non-ASCII in a folder name completely breaks Publish/template export — see the
section "⚠️⚠️ Non-ASCII folder name of a page/visual breaks Publish/template
export" below (before: `-replace '[^\p{L}\p{N}]', ''`, which kept letters
of any language/Unicode — that is enough for a normal save, but
not enough for Publish). Example: `"Cash Cure %"` → `CashCure`,
`"Collector #"` → `Collector`, `"Non-Cash Cure %"` → `NonCashCure`,
`"מכירות"` (Hebrew, no ASCII letters at all) → fallback (see below). The original
text with punctuation and any language is not lost — it stays as is in
`displayName`/`title.text`; only the folder name on disk changes.

**Fallback if sanitization yields an empty string** (for example, a `displayName`
entirely in Hebrew): for **pages** — `Page<N>`, where `N` is the 1-based position
of the page in `pageOrder` (not a hash and not an arbitrary collision counter — it matches
its actual place among the other pages, stable between runs). For
**visuals** — the already existing fallback to `visual.visualType` (`slicer`,
`card`, `shape`, ...) is always ASCII by itself; no additional logic was
needed.

Deduplication with a numeric suffix **within a single page** (not
globally — identical `shape`/`shape2` on different pages are fine).Syncs `name` in `visual.json` and the `visualInteractions` references in
`page.json`.

**Coordinate rounding (moved from the shelved `normalize_visuals.ps1`).**
For each visual (regardless of whether it is renamed or not)
`position.x/y/height/width` are rounded to integers —
`[long][Math]::Round([double]$vjson.position.$key, 0)`. It is important to cast specifically
to `[long]` (not leave it as `[double]`), otherwise `ConvertTo-Json` serializes
an integer value as `497.0` instead of `497` (Power BI does not use such a "tail"
when it writes). Visuals that are not renamed are saved in a separate pass
(Pass C saves only renamed ones — the rest need a separate step).

⚠️ **Both parts use a two-phase rename** (first everything needed → unique
temporary names, then → final names) — without this, entire rename chains
can fail (see the problems table below, "collision chain").

⚠️ **Page folders without `page.json` do not reserve their name.** If a folder
inside `pages/` does not contain `page.json` — it is not a real page (most
likely an incomplete save, see the section "Orphaned page folders" below).
Such a folder is reported in a separate warning `WARNING: found page
folder(s) with no page.json`, but **does not occupy** a slot in `$usedNames` — otherwise
it would permanently block the short name for a real page with the same
`displayName` (this was exactly the cause of the bug analyzed below).

**Part 4 — Display Folder for measures (optional, off by default,
added 2026-09-18).** Ported from the Tabular Editor Advanced
Scripting macro "Add Display Folder" (View/Apply), saved in
`C:\Users\ayrat\AppData\Local\TabularEditor\MacroActions.json` — it can now
be applied directly to TMDL files, without opening Tabular Editor. Unlike
Parts 1-3 (`.Report` only, always run), this part writes to the
neighboring `*.SemanticModel` — a structural change to the model, so it is
off by default and runs only with explicit flags:
- `-ShowMeasureDisplayFolders` — preview (`Table : [Measure] 'old' ->
  'new'` to the console), writes nothing to disk.
- `-SetMeasureDisplayFolders` — applies.

Rules (the same as in the macro):
- empty `DisplayFolder` → `__Measures`;
- already starts with `__Measures` → skip (already migrated, idempotent);
- exactly `_Measures` or `Measures` → `__Measures`;
- starts with `_Measures\` → `__Measures\<remainder>`;
- starts with `Measures\` → `__Measures\<remainder>`;
- everything else → `__Measures\<current folder>` (nesting).

The `_Measures` table and any table with the `FP_`/`CT_` prefix are excluded
unconditionally (the same exclusion as in the macro). It looks for `measure` only at
a 1-tab indent (in the `definition\tables\*.tmdl` files), in the same way
as `Get-TmdlConstructs` in `CleanUnused.ps1` — if a measure has no
`displayFolder:`, the line is inserted right before `lineageTag:` (every
measure in the model has one — verified across all tables 2026-09-18); if for
some reason `lineageTag:` is not found, the measure is skipped with a
warning instead of guessing the insertion point. `-SetMeasureDisplayFolders`
first unconditionally backs up the whole `*.SemanticModel` to `ClientA\BackUp\
RenameObjects_DisplayFolders_<timestamp>\` (the same principle as
`ReplaceModelTable.ps1`/`Find-UnusedMeasures.ps1`), then writes only those
`.tmdl` files that actually changed, with the same CRLF/fence integrity
check (`Test-TmdlIntegrity` equivalent) as `CleanUnused.ps1`.

Tested on `ClientA\Collateral\` 2026-09-18 (dry run,
`-ShowMeasureDisplayFolders`): found 26 measures to change (in both `Measure` and
`CollateralAction`/`CollectorAssignmentSnapshot` — i.e. it works not
only on the `Measure` table), readable output; `-SetMeasureDisplayFolders`
has not yet been run on any real model — it awaits explicit confirmation from the
user before the first live run (see `ClientA\CLAUDE.md`: model
structure changes — one-off, with verification and agreement, not automatic).
