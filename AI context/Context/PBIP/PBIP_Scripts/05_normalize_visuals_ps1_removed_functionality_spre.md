Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `normalize_visuals.ps1` — removed (functionality spread across other scripts)
It used to do two things: (1) rounding of `position.x/y/height/width` — **moved
to `rename_pages.ps1` Part 2** (see above; it already goes through every visual
for renaming, so there was no point in duplicating the pass); (2) replacing the font
`"Segoe UI"`/`"Segoe UI Semibold"` with `"Calibri"` — **deliberately not moved**,
deemed no longer needed (the whole project is already on `Calibri`, no new `Segoe UI` appear in
the project). If it is needed again — it was a simple text
replacement across the whole `visual.json`; the longer phrase `"Segoe UI Semibold"` was replaced
first, so as not to turn it into `"Calibri Semibold"`.

Both remaining scripts:
- save JSON as UTF-8 without BOM (`Save-JsonNoBom`, a shared function);
- **require PowerShell 7+ (`pwsh`)** and relaunch themselves under it if they
  were started under the old Windows PowerShell 5.1; if `pwsh` is not installed —
  the script stops with an explicit error instead of silently corrupting formatting;
- avoid name collisions when removing spaces/deduplicating.
