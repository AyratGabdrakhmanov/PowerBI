Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: drop the data before the user's refresh (ClientC, 2026-10-27)

When a model change needs a refresh anyway (new source, new columns) and the PBIP is closed: back up the
`.SemanticModel` folder (`<Project>\BackUp\<Task>_<timestamp>\`, it keeps `cache.abf`), then delete
`<Name>.SemanticModel\.pbi\cache.abf`. Desktop opens the model empty (no errors), the user's Refresh + Ctrl+S writes a
new `cache.abf`; I verify after that (timestamps, `PBI_ResultType`, DAX checks). Never with Desktop open; never refresh
myself (data on client servers).
