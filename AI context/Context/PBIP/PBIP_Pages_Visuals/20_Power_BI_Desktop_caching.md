Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## Power BI Desktop caching

Power BI Desktop caches information about the project:
```
%APPDATA%\Microsoft\Power BI Desktop\Cache\
Model_v2.Report\.pbi\localSettings.json
```

**Important (verified in practice):** in our case, clearing the cache **did not solve**
the problem of missing pages — the problem was in the actual data (spaces in
folder names), not in the cache. But if pages are still not visible after fixing the JSON files,
it is worth checking the cache as well:

1. Close Power BI Desktop
2. Delete the cache folder:
   ```powershell
   Remove-Item "$env:APPDATA\Microsoft\Power BI Desktop\Cache" -Recurse -Force
   ```
3. Delete the project's local settings:
   ```powershell
   Remove-Item "Model_v2.Report\.pbi\localSettings.json" -Force
   ```
4. Reopen Power BI Desktop
