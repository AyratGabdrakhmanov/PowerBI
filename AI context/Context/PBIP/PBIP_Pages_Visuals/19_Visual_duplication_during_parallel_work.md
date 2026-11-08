Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️ Visual duplication during parallel work

**Discovered in practice:** while the user works in Power BI Desktop
in parallel with manual/scripted editing of the project files, sometimes
**two visuals with identical content** are found on disk, sitting at
**exactly the same coordinates** (`position.x`/`y` match to the digit) —
only the `name` in `visual.json` differs (and, accordingly, the folder). Externally, in
Power BI Desktop, this looked like a single visual (the top copy covers the
bottom one), but on disk there are two full-fledged objects.

**Diagnosis:** for a suspicious pair — compare the content of `visual.json`,
ignoring the `name` field:
```powershell
diff (Get-Content $a -Raw) -replace '"name": "[^"]*"', '' (Get-Content $b -Raw) -replace '"name": "[^"]*"', ''
```
If there is no difference — it is an exact duplicate, safe to delete (provided
that neither `name` is mentioned in `page.json` → `visualInteractions`;
check with `grep` before deleting).

**The cause** has not been reliably established (possibly a repeated save by
Power BI Desktop over a file that had not yet "cooled down", or a copy/paste of a visual
that accidentally got into the same save) — in any case, before deleting
duplicates, get the user's confirmation rather than cleaning up automatically.
