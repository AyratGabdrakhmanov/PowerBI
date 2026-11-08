Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## 2. Power BI Desktop Bridge CLI — controlling the open Desktop

- npm `@microsoft/powerbi-desktop-bridge-cli` **1.0.0**, installed globally,
  command `powerbi-desktop`. Documentation:
  <https://learn.microsoft.com/en-us/power-bi/developer/agentic/power-bi-desktop-bridge-overview>.
- How it works: a named pipe `\\.\pipe\pbi-desktop-bridge-<PID>` inside
  each Desktop window, JSON-RPC; local only, one operation at a time.
- Commands:
  - `powerbi-desktop status [--pid N]` — the open file, `hasUnsavedChanges`,
    PBIR pages;
  - `powerbi-desktop reload [--pid N]` — ⚠️ does not re-read the Model view layout
    (`diagramLayout.json`, checked 2026-10-16) — that needs the file closed and reopened;
  - `powerbi-desktop reload` — ⚠️ **a large model change may not be applied** (2026-10-20, ModelWork
    merge: 30 s timeout, then `success`, but `INFO.MEASURES ()` still showed the old model and
    `hasUnsavedChanges` became `true`). Always check the live model after a reload; if unchanged — the user
    closes without saving and reopens (`PBIP_Scripts.md` → "`MergeSemanticModel.py`"). Also a **small** edit
    (ClientB 2026-11-04: 2 measure expressions in `_Measures.tmdl` + report JSON): `success`, the report part applied,
    the measures stayed old (`INFO.MEASURES ()` `ModifiedTime` unchanged). Fix without closing: set the same
    expressions live via MCP `measure_operations Update`, then `SaveDesktop.ps1 -Expect`;
  - `powerbi-desktop reload` — ⚠️ **model deletions are applied inconsistently** (ClientD Finance 2026-10-23,
    `CleanUnused.ps1 -Port`): this time the apply DID remove 7 tables / 31 measures / 23 columns deleted in TMDL
    (Desktop then showed "Semantic model out of sync"), unlike ClientB 2026-10-15. Restoring the files and applying
    again did **not** add them back. Recovery: TOM — deserialize the backup TMDL (`TmdlSerializer`, as
    `ValidateTmdl.ps1`), `Clone()` the missing tables / columns / measures, re-create relationships, `Calculate`.
    M tables come back without data (user refreshes them). Always compare the live model with the files after an apply;
  - `powerbi-desktop open` — ⚠️ **an expired Microsoft account sign-in blocks the open** (ClientC 2026-10-30):
    Desktop shows the login window (not seen by `CaptureDesktopWindow.ps1`, no dialog listed), the main window
    stays an empty `Untitled`, `status` → `BRIDGE_ERROR` "Host is not ready", trace logs empty. Not a model
    problem (TMDL valid). The user signs in or cancels the login; then the file loads. Do not retry opens in a loop.
  - `powerbi-desktop reload` — ⚠️ **PBIP only**: on a `.pbix` it fails with
    `REPORT_DIR_REQUIRED` (2026-10-17, ClientB `Blank_Report.pbix`). In a `.pbix`, TOM edits to M
    (parameters, new M-partition tables) land in the model and are written by Ctrl+S, but Transform
    Data / the Data pane keep showing the old queries until the file is closed and reopened (ask
    first; the close prompts "Save?" even with nothing new — Save is safe after a TOM save);
  - `powerbi-desktop reload` — ⚠️ **can restart Desktop** (ClientB compare copy 2026-10-25: the window came back as a new
    process, new pid and model port) — MCP connections / traces on the old port are gone; re-check pid and port after it;
    ClientC 2026-11-05: `reload` → `CONNECTION_LOST` and the window **closed** (no new process). Reopening then gave an
    empty "Untitled" window with no visible error (status `currentFilePath: ""`, "Host is not ready") — the cause was a
    TMDL error in my edit (the Frown dialog went to the user); so an empty Untitled after `open` = **load error**: check
    the TMDL (`PBIP_Model_Live.md` → `formatStringDefinition`), don't open again. Every retry left one more empty window;
    `CloseMainWindow()` does not close it, `Stop-Process` is blocked by the auto-mode classifier — the user closes them.
    Several PBIDesktop windows on one `.pbip` with no user action are a sign of the same thing;
  - `powerbi-desktop reload [--pid N]` — re-read the PBIP from disk (=
    Apply external changes). ⚠️ **It does not check the unsaved-changes flag —
    unsaved edits in Desktop are lost.** Before `reload` always run
    `status`; if `hasUnsavedChanges = true` — first Ctrl+S by the user
    (as item 9 in `PBIP_Model_Live.md`);
  - ⚠️ **a freshly opened PBIP can show an older page than the files** (Thin Scorecard 2026-10-28: `TabsBucketSummary`
    copied from the main report with `shutil.copytree` (keeps the old mtimes) — Desktop opened the report and showed
    the previous table; `reload` showed the new one). After copying pages by script, screenshot the page; if it does
    not match the files, `reload` (when `hasUnsavedChanges` is false);
  - the whole window (ribbon, banners, dialogs) — not the bridge: `CaptureDesktopWindow.ps1 -ProcessId <pid>`
    (`PBIP_Scripts.md`);
  - `powerbi-desktop screenshot <pageId>` / `screenshot-all` — PNGs of pages;
    ⚠️ right after `reload` / opening, wait ~20 s — a shot taken at once showed an **empty matrix**
    (ClientB 2026-10-26: rendering not finished, the data was fine);
    ⚠️ Desktop shows field **names, not culture captions** — to see translated headers, open a copy with
    `displayName` = the caption on the visual fields + the language filter switched (ClientB 2026-10-26);
    ⚠️ it captures only the **visible part of the canvas** at Desktop's current zoom —
    visuals near the page edge are cut off. **Always set "Fit to page" first** (user rule,
    2026-10-15): UI Automation on the Desktop window → button `Fit to page` →
    `InvokePattern.Invoke()`:
    ```powershell
    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
    $A = [System.Windows.Automation.AutomationElement]
    $root = $A::FromHandle((Get-Process -Id <pid>).MainWindowHandle)
    $c = New-Object System.Windows.Automation.PropertyCondition($A::NameProperty, 'Fit to page')
    $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $c) |
        Where-Object { $_.Current.ControlType.ProgrammaticName -eq 'ControlType.Button' } | Select-Object -First 1 |
        ForEach-Object { $_.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke() }
    ```
    The button is found without opening the View tab. Side effect: Desktop sets
    `hasUnsavedChanges = true` (page view is saved with the report) — tell the user, or
    take the screenshots before other edits.
    **Model view** (2026-10-28): tab `Name = 'Model view'` (TabItem → `SelectionItemPattern.Select()`); Fit to page =
    AutomationId `fitToPageButton`. **Properties pane collapse** (`>>`, tooltip "Collapse"): UIA sees it as a Button
    `Name = 'Expand'`, class `dismiss-button`, left of the `Data` pane — `Invoke()` does nothing; a real mouse click at its
    centre works (window brought forward + foreground pid checked, then `SetCursorPos` + `mouse_event`). The pane
    state is not saved with the report or in `User.zip`. Whole-window capture: `CaptureDesktopWindow.ps1`.
  - `powerbi-desktop open <file.pbip>`, `manifest`.
  - **F12 = Save As** in Desktop 2.158 (opens the Windows dialog; from a PBIP it proposes `<name>.pbix` in the same folder,
    `.pbix` type preselected; the name / type boxes expose no UIA patterns) — used by `SavePbipAsPbix.ps1`.
  - ⚠️ **Keys need the foreground:** while a Remote Desktop (`mstsc`) window is active, `SetForegroundWindow` fails and no
    keys may be sent (Ctrl+S, F12) — the save scripts wait / stop and ask the user to click the Power BI window.
- Enabling: Desktop → File → Options → **Security** → Desktop Bridge →
  "Enable external tool access to Power BI Desktop through secure local
  APIs" (on by default). Registry policy
  `HKLM\SOFTWARE\Policies\Microsoft\Power BI Desktop\DesktopNamedPipeBridge`
  (not set on this machine).
- ⚠️ **Status as of 2026-10-14: does not connect.** The
  `pbi-desktop-bridge-<PID>` pipes exist, but Desktop **2.157.879.0 (26.08)** drops
  the connection (`NO_BRIDGE`, "Lost the connection… before it answered").
  Restarting Desktop did not help; a raw JSON-RPC request to the pipe — "Pipe is
  broken" (Desktop accepts the connection and immediately closes it, the CLI is not at fault).
  In Options → Security there is **no Desktop Bridge section at all** (user's
  screenshots 2026-10-14) — build 26.08 does not have the feature yet, the pipe
  is created as a stub. Solution — Preview features (if there is an option there)
  or updating Desktop to 2026-09+.
- ✅ **Resolved 2026-10-14: works on Desktop 2.158.1304 (26.09)** — both the Store
  and the standalone install were updated to it. End-to-end test on a copy of
  Collateral (`ClientA\BackUp\2026-10-14_ToolTest\`): `status` → `screenshot` (before)
  → `pbir set` card title → `reload` (6 s) → `screenshot` (after) — the change
  showed, nothing else moved. Right after opening a file `status` first returns
  `Host is not ready` (use `--wait-seconds`), and Desktop may flip
  `hasUnsavedChanges` to `true` by itself shortly after load — on a test copy
  `reload` is safe anyway; on a real file ask the user before `reload`.

#### Reading screenshots: OCR for text, DAX for numbers, image for layout (2026-10-14)

[`Scripts\OcrImage.ps1`](<../../../Scripts/OcrImage.ps1>) — built-in Windows
OCR, local and free; prints `X|Y|text` lines (original-image pixels, top-to-bottom).
Needs Windows PowerShell 5.1 (WinRT), not pwsh:
`powershell -ExecutionPolicy Bypass -File OcrImage.ps1 -Path page.png [-Upscale 2] [-OutFile page.txt]`.

Test on the Collateral Overview page (44 known titles/labels/numbers):

| Screenshot | OCR found | Time |
|---|---|---|
| `--scale 1` (1517×932) | 14/44, and misread 14,163 as 11,163 | 0.8 s |
| `--scale 1` + `-Upscale 2` | 43/44 | 0.9 s |
| `--scale 2` (default of `powerbi-desktop screenshot`) | 43/44 | 0.9 s |
| `--scale 3` | 44/44 | 1.0 s |

Rule — which check, which tool:

| Check | Tool | Cost |
|---|---|---|
| Title/label changed, text present | `screenshot` (default scale 2) → `OcrImage.ps1` | ~1k tokens of text, grep-able |
| Numbers correct | DAX query (MS MCP / `QueryOpenModel.ps1`) — exact, no image | ~200–500 tokens |
| Layout/look (overlaps, sort order, colors, alignment) | the AI views the PNG itself (crop to the visual when possible) | ~1.5–1.9k tokens per page |

Never treat a scale-1 OCR number as a fact. OCR alone misses visual problems — e.g.
the first test showed unsorted years/months and repeated totals in the Collateral
matrices, visible only on the image.

`-Enhance` (grayscale + auto-contrast + bicubic enlargement, as in the lesson-notes
`prep.py`) is **off by default**: on Power BI screenshots it made results worse
(scale 1: 7/44 vs 14/44; scale 1 + `-Upscale 2`: 17/44 vs 43/44) and only nudged
scale 2 from 43 to 44/44. Desktop renders clean, high-contrast text — the clean-up
only harms anti-aliased small text. Use it only for pale text on video frames/photos.
Grayscale affects only the temporary OCR copy, never the screenshot.

#### Verifying an edit: `CompareScreens.py` (before vs after)

[`Scripts\CompareScreens.py`](<../../../Scripts/CompareScreens.py>) —
`py -3.12 CompareScreens.py before.png after.png [--expect x0,y0,x1,y1] [--out DIR] [--no-ocr]`
(Pillow + numpy; techniques from the lesson-notes pipeline: frame diff, OCR of only
the new lines, crop + enlarge). Prints, per changed region: position and size,
**colors of the changed pixels** before/after (hex — for color checks; the diff
uses all three channels, so a same-brightness color change is still caught), OCR
lines removed/added (or "text unchanged (change is visual only)"), and saves a
side-by-side crop `region_N.png` (before | after). With `--expect` (the area meant
to change, e.g. the visual's box) it warns about every change outside it — side
effects.

Tested 2026-10-14 on the Collateral copy (card title edits):

| Edit | Report (≈100 tokens of text) |
|---|---|
| title text `Reinstatement #` → `Reinstatement # (TEST)` | 1 region 128×16 px, `- Reinstatement #` / `+ Reinstatement # (TEST)`, all inside `--expect`; 2.4 s |
| title font color → `#C00000` | 1 region, changed-pixel colors `#000000`/`#808080` → `#C00000`/`#E08080`, "text unchanged" |

The region crop is ~620×80 px (~70 tokens to view) instead of a full page
(~1.7k tokens; two pages to compare — ~3.4k).

Verify loop: `screenshot` (before) → edit (`pbir set` / TMDL) → `pbir validate` →
`status` (no unsaved changes) → `reload` → `screenshot` (after, same `--scale`) →
`CompareScreens.py --expect <visual box>` → view `region_N.png` only if the look
matters → numbers via DAX.
