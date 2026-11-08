Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 40. Home page defined (⚠️ RULE, all projects, user 2026-11-02)

The report has a home page: `pages.json` `landingPageName` (the report always opens on it; `activePageName` = only the
page active at the last save). If `landingPageName` is missing, **ask the user which page is the home page** — do not
guess. Set `activePageName` to the same page. Before 38 (it keeps the landing page as the only visible page).
Check: script — `landingPageName` exists and names a page in `pageOrder`.
