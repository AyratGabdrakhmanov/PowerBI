Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 16. Canvas settings: vertical alignment Middle (all projects, user 2026-10-28)

Every page: Format → Canvas settings → Vertical alignment = **Middle**. PBIR `page.json`:
`objects.displayArea[0].properties.verticalAlignment = { "expr": { "Literal": { "Value": "'Middle'" } } }` (create
`objects` / `displayArea` when missing; keep other page objects). Report files only, all pages incl. hidden / tooltip
ones; theme default `visualStyles.page.*.displayArea` is a backup, the page setting wins. Reference: ClientF Sales
`Page1`; script logic `PBIP_Scripts.md` → `rename_pages.ps1` Part 1b. Check: `pbir validate`, screenshots.
