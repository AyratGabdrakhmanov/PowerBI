Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️ Three places in `report.json` reference the theme file by name — same as with pages/visuals

The same "N critical places must match" principle as with pages
(folder name / `pages.json` / `page.json`) and with page references inside
`visual.json` (`navigationSection`/`section`/`drillthroughSection`) —
only here the reference to the **custom theme file by its name** appears
in exactly **three** places in `definition/report.json` (verified on
`Collector Assignment.Report`, 2026-09-19):

```json
"themeCollection": {
  "customTheme": {
    "name": "Classroom7947196837311171.json",   // 1️⃣
    "type": "RegisteredResources"
  }
},
"resourcePackages": [
  {
    "name": "RegisteredResources",
    "items": [
      {
        "name": "Classroom7947196837311171.json",  // 2️⃣
        "path": "Classroom7947196837311171.json",  // 3️⃣
        "type": "CustomTheme"
      }
    ]
  }
]
```

Plus the physical file itself on disk:
`StaticResources/RegisteredResources/<same name>.json`.

**Renaming/replacing the theme file (for example, when deploying a new theme
under a different name) requires updating all three JSON references at once** —
otherwise you get a silent failure of the same class as with pages/visuals (Power BI does not
warn about a non-existent theme, it simply does not pick it up or falls back
to the default).

**The safe way to edit `report.json` is a targeted text replacement of the
file-name string, not a full `ConvertFrom-Json`/`ConvertTo-Json`
round-trip.** `report.json` is a large and complex file (filters, `objects`,
`resourcePackages`, `settings`, extensions); a full rebuild via
`ConvertTo-Json` risks the same class of problems already documented
for numbers (`497` → `497.0`, see "Numeric serialization in PowerShell" above) —
but on a file of this size the blast radius is much larger and harder to
check by eye. Since the theme file name is one and the same unique
string in exactly those three places (and does not appear anywhere else in the file
by accident), it is safer to do a plain text replacement
(`$json.Replace($oldName, $newName)`) over the raw file text, counting
the number of occurrences **before** the replacement as a sanity-check (it must be exactly 3 if
the structure has not changed) — and write the result back as is, without touching
the rest of the file's formatting. Implemented in `Rename-ReportTheme.ps1` (see
"Scripts" below).

The theme schema (`reportThemeSchema-2.159.json`, published by Microsoft separately, not part
of the PBIP project) is worth downloading and keeping nearby — it describes **all** allowed
theme fields, including those absent from the project's specific theme file. Load it like this:

**⚠️ The source and versioning of this schema are not the same repository as for
`visualContainerSchema`/`page` (verified 2026-09-19).** `reportThemeSchema`
is NOT published in `microsoft/json-schemas` (there is neither `theme` nor
`reportThemeSchema` there at all — verified against the `fabric/item/report/` tree), but in
the separate repository **`microsoft/powerbi-desktop-samples`**, folder
`Report Theme JSON Schema/`. Versioning there is the **Power BI
Desktop build number** (`2.157` = Desktop build, not semver of the form `x.y.z`), not
the version of the schema itself as an artifact — so the file has no `$id` (unlike
`page-2.1.0.json`/`visualContainerSchema`, which come from `microsoft/json-schemas`
and do have `$id`). At the time of checking, `2.157` (August 2026, exploration version
`5.76`) is the latest version in this folder; there is no newer one yet, nothing
to update from. At the next check, look specifically in this folder
(`github.com/microsoft/powerbi-desktop-samples/tree/main/Report%20Theme%20JSON%20Schema`),
not `microsoft/json-schemas`.
```powershell
$schema = Get-Content "reportThemeSchema-2.159.json" -Raw | ConvertFrom-Json -AsHashTable
```
(specifically `-AsHashTable` — plain `ConvertFrom-Json` fails with an error on keys that differ
only by case, such as `gridlineColor`/`gridLineColor`, which do occur in the schema).
