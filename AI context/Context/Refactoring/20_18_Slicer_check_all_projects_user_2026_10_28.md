Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 18. Slicer check (all projects, user 2026-10-28)

1. **No "is not blank" filters on slicers** (visual-level `Not In (null)` on the slicer's own field, often locked): a
   blank item means a modelling problem (fact keys without a dimension row, a calendar that does not cover the facts) —
   fix it in the model / SQL, then delete the filter. Never hide blanks in the slicer. **Exception — date slicers**
   (user 2026-11-05): a blank Calendar member made by an *inactive* date relationship (e.g. `Sales[DueDate]` with old
   wrong dates, ClientC 5 rows from 2002) → every Calendar list slicer gets the visual filter `[Show Existing Sales] = 1`
   (not a not-blank filter); range (Between / Relative) slicers do not show the blank and need nothing.
2. **Month + year = the calendar hierarchy:** a slicer on a flat `'Calendar'[Month Year]` list → the hierarchy
   `'Calendar'[_Year-Month SortBack]` (`Year SortBack` → `Month SortBack`, latest first; reference Calendar — named
   `_Year-Month Slicer` / `… Slicer` before 2026-10-30; rename an older project with `Refactoring\calendar_sortback.py`). Carry over the saved selection
   (e.g. `Month Year = 2026-02-01` → Year 2026 / Feb), single / multi select, dropdown mode, title, sync group; repoint
   bookmarks that store the old selection; measures that read `MAX ( 'Calendar'[…] )` keep working.
3. **Customer / item slicers = name → code hierarchy** (user 2026-10-28): a slicer on the combined text column
   (`Customers[CodeNameBP]` "12409 | name", `Items[CodeNameItem]`) → a hierarchy whose top level is the **name** and the
   level under it the **code** (`Customers`: `CardName` → `CardCode`; `Items`: `ItemName` → `ItemCode`; with a group level
   above when the slicer already had one, e.g. `CardGroup` → `CardName` → `CardCode`). Users see names; the slicer
   search also matches the code level, so they still find a customer / item by code; two customers with the same name
   stay apart at the code level. Model: hierarchies named with `_` (`_Customer`, `_Item`, `_Customer Group`; rule
   `BP_HIERARCHY_PREFIX_UNDERSCORE`); saved selections / bookmarks on `CodeNameBP` → the matching name + code; the
   combined column stays for tables until unused.
4. **Multi-field slicers = a model hierarchy** (user 2026-10-28; **also charts / tables**, user 2026-11-05: separate
   Calendar columns in one role, e.g. axis `Year` + `Month Name` → `_Year-Month` levels, ascending on axes —
   `ClientC\Sales New\Refactoring\CalendarFieldsToHierarchy.py`): a slicer whose fields are listed ad hoc on the visual
   (e.g. `Items[ItemGroup]` + `Items[CodeNameItem]`, `'Calendar'[Year]` + `[Month Name]`) → a hierarchy defined in the
   model. **Standard hierarchies — always, every model** (⚠️ RULE, user 2026-10-30): the customers table gets
   `_Customer Group` (group → `CardName` → `CardCode`) and the items table `_Item Group` (group → `ItemName` → `ItemCode`)
   even when no visual uses them yet: the group level gives a short first list, the name level is what users search and
   select, the code level makes the code searchable. Level names = column names; He / En captions on the hierarchy and
   levels where the project has cultures. ClientB Inventory Coverage `Inventory[_Item Group]` (`ItmsGrpNam` → `ItemName` →
   `ItemCode`, 2026-10-30). **Calendar: only the existing Calendar hierarchies** (`_Year-Month SortBack`, `_Year-Q-Month`, … from the
   reference Calendar) — never create new date hierarchies. **Customers / items:** create the hierarchy when missing
   (prefix `_`, rule `BP_HIERARCHY_PREFIX_UNDERSCORE`); the combined `CodeName*` column is never a level — split it into
   the **name** level, then the **code** level under it (group → name → code). One hierarchy per real grouping column
   (`Customers[CardGroup]` and `[CustomeGroup]` are different groupings → two hierarchies). Existing hierarchies without
   `_` or without the code level (ClientE `ItemHierarchy`, `CardHierarchy`) → extend / rename and repoint the visuals
   that use them. Saved selections / bookmarks → the hierarchy levels. Calendar level names are NBSP × level (`' '`,
   not spaces) in `Level` / `queryRef` / `nativeQueryRef` — with plain spaces the slicer shows "Fix this". An inverted
   (exclusion) selection on `CodeNameBP` maps to `Not In` (name, code) tuples (check the mapping by DAX first: one row
   per code).
5. **Year-only slicers are deleted** (user 2026-10-28): the year comes from a calendar hierarchy slicer
   (`_Year-Q-Month`, `_Year-Month Slicer`; it takes over the saved year) or from `Month Year Current`. Remove the
   deleted slicer from `visualInteractions`, bookmark states and `targetVisualNames`; a page that would keep no calendar
   slicer keeps its Year slicer (list it for the user). Check the page by DAX (a Year slicer saved on another year than
   `חודש נוכחי` showed an empty page).
6. **No slicer on a field fixed by a report-level filter** (user 2026-11-05): e.g. document status `Open` / currency
   `Local` set on the report level → a slicer on `CT_DocStatus` / `CT_Currency` can only show that value → delete it
   (+ bookmark states, `visualInteractions`; the panel slicers below it move up). Calendar slicers stay (the report
   `Closed Period` filter only cuts future dates). ClientC `Sales NEW` 2026-11-05: 1 (`דשבורד מכירות`, doc status).
Check: list every slicer with a not-blank filter, a flat month field, a `CodeName*` field or ad-hoc fields (script over
`visual.json`), screenshots before / after, the saved selection gives the same numbers.
