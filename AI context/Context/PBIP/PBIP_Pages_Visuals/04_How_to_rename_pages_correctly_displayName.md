Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## How to rename pages correctly (displayName)

### The only safe way
1. Change `displayName` in `page.json` (spaces allowed — this is for the UI)
2. Rename the folder to the **space-free** version of the new name
   (for example, `"Sales YTD"` → folder `SalesYTD`)
3. Update the `"name"` field in `page.json` to the same space-free name
4. Update the references in `pages.json` (`pageOrder`, `activePageName`, `landingPageName`)
5. Save both JSON files as UTF-8 without BOM, with 2-space indents

All these steps are automated in the scripts below.

### Handling name collisions
If two pages' `displayName` values coincide after removing spaces
(for example, `"Duplicate of Collector Assignment"` and `"Duplicate of CollectorAssignment"`
both give `DuplicateofCollectorAssignment`) — you need to add a numeric
suffix (`DuplicateofCollectorAssignment2`), otherwise one of the folders will be
skipped or there will be a conflict during renaming.
