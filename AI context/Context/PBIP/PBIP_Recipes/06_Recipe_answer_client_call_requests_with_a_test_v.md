Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: answer client call requests with a test version (2026-10-23)

Use this when the user says "do them all in a test version, then we review one by one" (first used for
the Collector Assignment requests 2c, 2d, 3 and 4 from the 13 Oct 2026 call). The aim is **one test copy
that answers every open request, built without questions**. Each guess is written down as an assumption
for the review, and nothing is decided silently.

### 1. Collect the requests

- The **single source** is the status table in the call summary (`ClientA\Calls\<date>\<date>_Call_Summary.md`
  → "Status of the requests"). Read the transcript (`transcripts\*.txt`) for the exact words of every open
  item. The summary is condensed, and details such as "potentials are 13+" or "8 for both" are only in
  the transcript.
- **Watch the recording (`*.mkv`) where the client shares their screen** before writing any assumption.
  Find the moment in the `.srt` (grep a phrase from the transcript), take 2–4 frames with
  `ffmpeg -ss <hh:mm:ss> -i "<video>.mkv" -frames:v 1 <out>.png`, and read them. Numbers that are only
  "on screen" (e.g. Manny's 31+ weights in Excel lines 23–27, 2026-10-13 call at 14:00) are in the video,
  not in the transcript. Skipping this on 2026-10-23 turned a known value into a "question for the client".
  Save the frames used as evidence in `Calls\<date>\frames\<hhmmss>.png` (video time, `-vf scale=1600:-1`).
  Record them in the call summary → "What the recording shows" (time | screen | finding), and refer to the
  frame time in the assumption or answer it settles. Look for the client's own files on screen: there the
  2026-10-13 call showed the weights sheet, and two Excel reports that are effectively the Roll Rate
  template.
- Check `ClientA_Context.md` → "Open questions" and any contract in `Semantic Model\Contracts\` that
  touches the same data. An earlier contract can settle a question that looks open (e.g. C-CA-49 Q1:
  the balance at assignment start is accepted as the balance).

### 2. Check the data before designing (read-only)

- Query the **open real model** read-only (MS Modeling MCP → `ListLocalInstances` → `Connect` by window
  title → `dax_query_operations Execute`). Use `DEFINE MEASURE 'Measure'[X] = …` to try a new measure
  without touching the model (quote `'Measure'`, because the bare name is a syntax error).
- Look for the field the client means first. If it does not exist (e.g. there is no team field), derive
  it from the data. Then check the derivation against the example the client gave on the call (Vanessa:
  1 - 10 to May, 11 - 30 from June).
- For a formula change, compare old and new results side by side on one closed month before building
  visuals, and note who changes.

### 3. Build the test copy

- Copy `Semantic Model\Semantic Model.pbip` + `.Report` + `.SemanticModel` (with `.pbi\cache.abf`, so the data is
  there without a refresh) to `ClientA\BackUp\<date>_TestVersion\`. Give it a **different name**
  (`CA TEST.*`):
  - `.pbip` → `artifacts[].report.path`;
  - `definition.pbir` → `datasetReference.byPath.path`;
  - both `.platform` → `metadata.displayName`.
  The Desktop window then shows `CA TEST`, and the MCP port cannot be confused with the real file.
- Edit the TMDL and `visual.json` files with scripts in the scratchpad. Bash heredocs with long Python
  break on quotes, so write the `.py` file first.
- Every model object gets a comment with its source ("call 2026-10-13: …") and, where it is a guess, the
  word **TEST assumption**. Follow `BPARules_ClientA.json` as for production code.
- **New pages:** copy the shell of a sibling page (left navigation buttons + slicer panel + page
  filters that still apply), then drop its content visuals. Make the page visible (no
  `HiddenInViewMode`) until it gets a navigation button. Add it to `pages.json` → `pageOrder` after
  its parent page.
- **`pbir validate`**: compare with the real report. Only `SCHEMA_*` notices may be new.
- **Single-select slicer default:** with `strictSingleSelect` and no saved selection, Desktop selects the
  **first** value (Roll Rate MTD showed "1 - 10" instead of "11 - 30"). Save the default in
  `visual.objects.general[0].properties.filter.filter` (`Version 2`, `From` the table, `Where In` with the
  value), the same shape as the `MonthPeriod` slicer.
- **New calculated table in the test copy:** `powerbi-desktop reload` does not load model changes, and the MS
  MCP cannot create a calculated table. Close only the test-copy Desktop (find it by window title `CA TEST*`)
  and run `powerbi-desktop open` again. All test changes must already be in the files. The "Auto recovery
  contains recovered files" banner afterwards is harmless.

### 4. Verify in Desktop (test copy only)

- `powerbi-desktop open "<…>\CA TEST.pbip"`, then wait in the background until `status` lists the file.
  The open recomputes the calculated tables and columns, so no refresh is needed.
- MCP `Connect` to the `CA TEST` window and run the same checks as in step 2, now on the real objects.
- Click Fit to page (UI Automation), then run `powerbi-desktop screenshot <page> --pid <pid>`, and look
  at every new or changed page. The screenshot catches what queries miss: in this session it caught a
  trend chart showing one day only.
- Fix live in the test model (MCP `measure_operations Update`) **and** in its TMDL. The "changed
  externally" banner on the test copy is expected. Do not save Desktop.

### 5. Hand over for review

- Set each item in the status table to "🧪 Test version, under review". Add a table "Test version for
  review" with columns **#**, **What was built**, and **Assumptions to confirm**.
- Split the open questions into **client** questions (business meaning: weights, team definition,
  layout) and **our** questions (navigation, Thin report, which page replaces which).
- Port to the real report only item by item, after the user approves each one, following the usual
  rules (backup, git commit, Desktop open → TOM/MCP live + files).
