Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## Invisible hierarchy level names — use quoted NBSP, not zero-width spaces (2026-10-14)

**Why invisible names:** our `Calendar` hierarchies (`Year-Month`, `Year-Month Slicer`,
`Year-Q-Month`, `Year-Q-Month-Date`) hide their level names so the Data pane and field
tooltips show only the hierarchy. Names must still be unique within a hierarchy, so
level N gets N invisible characters.

**The problem:** the old names were runs of zero-width spaces (U+200B), written by
Desktop unquoted: `level ​`, `level ​​` … Desktop and Tabular Editor 2 accept them, but
the TOM TMDL loader used by the MS Power BI Modeling MCP (`ConnectFolder`, offline)
fails: "TMDL objects cannot be merged because both declare the same property:
lineageTag … Level '​' … Level '​​'". It compares names culture-aware, and that
**ignores every zero-width/format character** — U+200B, U+200C, U+200D, U+2060, even
mixed, all collapse to an empty name.

**Tested 2026-10-14** (scratch copies of Journal Entries, MCP `ConnectFolder`):

| Level names | Result |
|---|---|
| `​` × N (current) | ❌ duplicates |
| one different zero-width char per level (200B/200C/200D/2060) | ❌ duplicates |
| mixed zero-width sequences | ❌ duplicates |
| NBSP × N, unquoted | ❌ TMDL syntax error (read as whitespace) |
| **NBSP × N, quoted** — `level ' '` | ✅ loads, export round-trip keeps it |
| Braille blank U+2800 × N, unquoted | ✅ loads (backup option — may render differently) |

Then on a Desktop test copy with quoted NBSP: Desktop opens it with no errors, levels
are char 160 with lengths 1–4, no broken objects, the hierarchy slicer works, and
**Ctrl+S keeps the names** (Desktop writes them quoted).

**Rule:** invisible level names = **U+00A0 (NBSP) × level number, quoted** in TMDL —
`level ' '`, `level '  '`, `level '   '`, `level '    '`. In JSON templates —
`"name": " "` (NBSP inside the string).

**Converting a model (zero-width → NBSP)** — backup first; Desktop closed:
1. TMDL `tables\Calendar.tmdl`: replace each `^\t\tlevel (\u200B+)$` with
   `level '` + NBSP × (run length) + `'`.
2. **Report:** visuals reference levels **by name** — `"Level"`, `queryRef`
   (`Calendar.Year-Month.​`), `nativeQueryRef` (`Year-Month ​`), `queryRefs` in
   `visual.json` (also check bookmarks). Replace each run of `\u200B` with the same
   number of `\u00A0` in every report file that contains U+200B; verify JSON parses
   and no U+200B is left.
3. Open → check `INFO.LEVELS()` (`UNICODE([Name]) = 160`, lengths) and broken objects →
   screenshot the visuals using the hierarchy → save.
31. **Text renames break M step names silently** (ClientB 2026-10-27): a rename that skipped M lines with `Item="…"`
    renamed the `in` reference but not the step on the navigation line (`dbo_ETL_MD_X` vs `dbo_X`). `ValidateTmdl.ps1`
    does not evaluate M, so it passes; the refresh fails. After any text edit of M: check that the name after `in` is a
    defined step in every partition (regex check in `Refactoring\ClientB\model_conventions.py` history, ClientB 2026-10-27).
32. **A new DAX table stays empty after a refresh** (ClientB `CT_DocumentType`, 2026-10-27): the calculation step of the
    refresh failed on an old error elsewhere — a field parameter whose label (and field) column is sorted by `Order` while
    one label has several orders ("Cannot order …"). The data loads, calculated objects not yet built stay empty
    (`INFO.PARTITIONS` `RefreshedTime` 1699); later refresh / Calculate commands do not build it either. Check after any
    refresh: `TMSL refresh calculate` messages and empty calculated tables. Fix: one order per label (repeated labels get
    U+200B suffixes), no sort on the hidden `Fields` column; never `sortByColumn` on a `userContext` column. A table switched from Power Query to DAX in the files can stay a "Ready but empty" object in the cache (no storage; refresh /
    Calculate / ClearValues / a new partition do nothing): recreate it live — set its culture translations and relationships
    aside, `Tables.Remove` + `Add(Clone())`, `RequestRefresh(Calculate)`, restore both, save (ClientB 2026-10-27, 6 rows back).
33. **Renaming calculated columns / DAX-table columns on closed files is safe** (ClientC step 32, 2026-10-31, 24 columns):
    rename in TMDL + report, `powerbi-desktop open`, `RequestRefresh(Calculate)` → 0 objects in error, values identical
    (unlike import tables, gotcha in `Refactoring.md` step 4). Two traps on the way: (a) Python `open().read()` turns CRLF
    into LF, so writing back changes every line — read with `newline=''` or restore the endings
    (`Agency\ClientC\Refactoring\Step32_restore_eol.py`); (b) `QueryOpenModel.ps1 -ListInstances` returned nothing and the
    MSI `msmdsrv` showed no listening port in `Get-NetTCPConnection` — the newest `msmdsrv.port.txt` gave the port; confirm
    the model by an object only it has (a renamed column) before any write.

Status: template `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\DAX PRO Solutions\Calendar.json` converted 2026-10-14; still
zero-width — `ClientA\_Documentation\Calendar.json`, `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\DAX PRO Solutions\Calendar.pbix`
(binary, via Desktop) and the real models (list — `ClientA_Context.md`, "Open questions" 4).
**Collector Assignment converted 2026-10-16** (user: "apply calendar from main source"):
`Calendar.tmdl` + 21 report `visual.json` (slicers/charts on the hierarchies), backup
`ClientA\BackUp\2026-10-16_CalendarNBSP_CollectorAssignment`; `INFO.LEVELS()` = 11 levels,
char 160, lengths 1–4; the MCP connects to this model again (before the fix it could not:
offline `ConnectFolder` failed, and the live `Connect` right after opening found no database).
