Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️⚠️ Orphaned page folders (without `page.json`)

**Discovered in practice:** a folder inside `pages/` that contains `visuals/` but
**no `page.json`** is not a page, but most likely the leftover of an incomplete
save (for example, a "Duplicate page" in Power BI Desktop interrupted by
parallel editing of the project files by a script/manually at the same
time). Power BI does not see it — like any page without `page.json` (a silent
failure, see "What Power BI does NOT do" below).

**How this used to break renaming:** the old version of `rename_pages.ps1`
reserved the name of such an orphan folder (`$usedNames[$folder.Name] = $true`)
without even checking that it was not a real page. Result — if the orphan happened
to have the same name as the *correct* short name of a real page (for example,
an orphaned `Details1` next to a real page whose `displayName` also
yields `Details1`), the real page permanently got a suffix
(`Details12`) instead of the clean name, on every run of the script.

**What it looks like on disk:**
```
pages/
├── Details1/          ← ⚠️ orphan: only visuals/, NO page.json
│   └── visuals/       ←    (an outdated subset of cards)
├── Details12/         ← the real page ("displayName": "Details 1")
│   ├── page.json
│   └── visuals/       ←    (the full current set of visuals)
```

**Diagnosis:** compare `visuals/` in the suspicious pair of folders — if
the "orphan's" content is a subset (by composition and/or outdated in
content) of what is already fully and correctly present in the paired page —
this is a hundred-percent sign that the orphan is safe to delete.

**Fix:**
1. In the script (already done) — orphans no longer reserve a name, they are only
   reported as a warning.
2. In the current project — the orphan must be deleted manually (`Remove-Item -Recurse`,
   with the user's confirmation — deletion is irreversible), then rerun
   `rename_pages.ps1` so that the real page gets the clean short name.
