Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Templates

- [`ClientA\_Documentation\Calendar.json`](<../../../Reference/DAX PRO Solutions/Calendar.json>) — definition of the
  calculated table `Calendar` in JSON (columns with formats, 4 hierarchies:
  `Year-Month`, `Year-Month Slicer`, `Year-Q-Month`, `Year-Q-Month-Date`),
  DAX — in `partitions[0].source.expression`. ⚠️ Its hierarchy level names are still
  zero-width spaces — they break the MCP's offline mode; convert to NBSP (section
  "Invisible hierarchy level names" in `PBIP_Model_Live.md`; the copy in
  `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\DAX PRO Solutions\` is already converted). **The main source is
  `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\DAX PRO Solutions\Calendar.json`** (global CLAUDE.md); since 2026-10-16 it has the
  new standard hierarchy names with `_` (rule `BP_HIERARCHY_PREFIX_UNDERSCORE`):
  `_Year-Month`, `_Year-Month Slicer`, `_Year-Q-Month`, `_Year-Q-Month-Date` + **`_Month-Date
  Slicer`** (`Month Year Slicer` → `Date Short`, as in Collector Assignment) and the columns it
  needs: `Month Year Slicer` (month start, `mmm yyyy`, sorted by `Month SortBack` — latest month
  first) and `Date Short` (`[Date]`, `dd mmm`); since 2026-10-29 `_Year-Month Slicer` level 0 = `Year Slicer`
  (sorted by hidden `Year SortBack` — latest year first, like `Month SortBack`); backups next to it `Calendar.json.bak-20261016`
  (before `_`), `…-2` (before `_Month-Date Slicer`), `…-3` (before `Month Year Slicer`). This `ClientA\_Documentation` copy is
  still old (names without `_`, zero-width levels).
  **Since 2026-10-30 (user): "Slicer" → "SortBack"** (= sorted latest first): visible `Year SortBack`, `Quarter SortBack`
  (new), `Month SortBack`, `Month Year SortBack`, `Date SortBack` (new) are sorted by hidden keys `… SortBack Key`
  (= −`… ID`; the old hidden `Year SortBack` / `Month SortBack` were renamed to `… Key`); hierarchies `_Year-Month SortBack`,
  `_Month-Date SortBack` and new **`_Year-Q-Month-Date SortBack`** (Year → Quarter → Month → Date, all latest first).
  Applied: reference + ClientB Sales_ClientB / Inventory Coverage (`Refactoring` script `calendar_sortback.py`); ClientC, ClientE,
  Collector still have the `… Slicer` names until re-applied. Backup `Calendar.json.bak-20261030-sortback`. Ideas inside:
  - range — 1 Jan of `TODAY()` year − 2 … 31 Dec of year + 1 (retention policy 2026-11-01, `Refactoring.md` 12; was ±3);
  - `Year ID`/`Quarter ID`/`Month ID`/`ISO Week ID` — offset from the
    current period (0 = current, negative = history) — "last N" filters
    without dates; ID format — `#,0`;
  - `Month SortBack` — the latest month on top in the slicer;
  - `IsWorking`/`Working Day Of Year` — the weekend is Friday and Saturday;
  - `Closed Period` — date ≤ today;
  - `ISO Week as Date` — the week number and the week end are encoded in the
    time of day → label `W09: 29.02 - 06.03`, while the column stays a
    date and sorts chronologically.
- [`C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\Maket\ThemeWarm.json`](<file:///C:/Users/ayrat/OneDrive/Документы/ClientA/_Documentation/Reference/Maket/ThemeWarm.json>) — a report
  theme with the `Warm` preset, see "Real-world example: the `Warm` preset".
