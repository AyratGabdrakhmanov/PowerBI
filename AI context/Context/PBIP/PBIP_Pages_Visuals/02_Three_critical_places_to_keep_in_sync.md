Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## Three critical places to keep in sync

Power BI requires everything to match in **three places**:

### 1️⃣ Folder name (⚠️ NO SPACES)
```
Model_v2.Report/definition/pages/SalesYTD/
```

### 2️⃣ Reference in pages.json
```json
{
  "pageOrder": [
    "SalesYTD",     ← must match the folder name, no spaces
    "CA_DQ",
    ...
  ],
  "activePageName": "SalesYTD",
  "landingPageName": "SalesYTD"
}
```

- `landingPageName` — the home page: the report always opens on it,
  whatever page was active at save time.
- `activePageName` — only the page that was active at save; it decides the
  opening page **only if `landingPageName` is not set**. With a landing page,
  a changed `activePageName` after Ctrl+S is noise — no action needed (ClientB,
  2026-10-14).

### 3️⃣ The "name" field in page.json (⚠️ NO SPACES)
```json
{
  "name": "SalesYTD",            ← must match the folder name
  "displayName": "Sales YTD",    ← what the user sees (spaces OK)
  "displayOption": "FitToPage",
  ...
}
```
