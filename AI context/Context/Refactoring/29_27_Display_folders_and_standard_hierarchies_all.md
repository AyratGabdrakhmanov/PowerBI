Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 27. Display folders `__` and standard hierarchies (all projects, user 2026-10-30)

Every display folder starts with `__` (BPA `BP_DISPLAY_FOLDERS_DOUBLE_UNDERSCORE`; `__Value`, `__Key`, `__Filter` …) so the
`_` hierarchies list below them (step 13 text). **Exception — `_Measures`:** a single `_` (`_Stock`, `_Color`, `_Tooltip`, `_Labels`;
BPA `BP_MEASURES_TABLE_FOLDERS_SINGLE_UNDERSCORE`, user 2026-10-30). Customers / items tables always get `_Customer Group` / `_Item Group`
(group → name → code), and item / customer slicers use them (step 18 rule 4).

⚠️ **Never a hierarchy level on a per-viewer translation column** (`USERCULTURE ()` / `expressionContext: userContext`, e.g. ClientF
`Customers[CustomerGroup]` = English display of `CardGroup`): the engine fails every Calculate with
`XMUserHierarchyLevelAggDataCache::InitDC` and Desktop shows "Unable to execute DAX" (ClientF Sales v2 2026-11-01). Such a column
is not "another grouping" — the hierarchy stays on the data column (`CardGroup`); check the DAX before adding a level.
