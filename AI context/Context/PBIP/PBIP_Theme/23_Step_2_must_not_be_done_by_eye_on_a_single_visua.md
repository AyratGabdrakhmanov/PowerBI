Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️ Step 2 must not be done "by eye" on a single visual — check against all "siblings" of the same type

Found in practice (Collector Assignment, 2026-09-19, moving the formatting of
`SalesSummary`/Overview into the theme + the `Warm` preset). Before deciding that a
visual property is a "shared style" (step 2 above, suitable for `visualStyles.<type>.*`,
i.e. the default for ABSOLUTELY all visuals of this type in the report), always
collect the same property from **all other visuals of the same
`visualType`** in the report (`grep -rl '"visualType": "pivotTable"'` etc., then
read `objects.<key>` on each one found) and compare the values:

- **Same on all/almost all** (for example `columnHeaders.bold: true`,
  `grid.gridHorizontal: true`, `grid.gridHorizontalColor: '#F3F3F3'` — these were
  identical on all ~15 `pivotTable` visuals in the report) → this is a genuine
  shared report convention, safe to move up into `visualStyles.<type>.*`.
- **Differs from visual to visual** (for example `columnHeaders.defaultColumnWidth`:
  100/99/105/110/66 — each has its own; `columnHeaders.alignment`: `'Right'`
  only on the reference visual, `'Center'` on all the others) → this is a deliberate
  targeted setting of a specific instance, not a convention. Moving it
  into `<type>.*` is **technically safe** (the local override in `visual.json`
  will still win over the theme — there will be no visible changes), but
  **semantically wrong**: a randomly chosen value of one specific visual would become
  the default for all future new tables. The right place is
  a named preset (step 3), not `<type>.*`.

**Practical consequence for "if possible" in phrasings like "move into the
theme, if not — into a preset":** "if possible" is not only about
technical schema validity (see below about `tableEx`/`pivotTable`), but also about
whether the value repeats across all similar visuals in the report. Without this
check it is easy to turn one visual's targeted design into a report default
that silently "goes off" only when someone creates a new table and
is surprised by how it looks.

**⚠️ "All or nothing" (see below) applies here too.** If a named preset
gets some key (`columnHeaders`/`grid`/`values`/...) with even one
property that differs from the shared level, the preset must **repeat inside
itself all** the other properties of this key that have already been moved up into `<type>.*`,
rather than rely on them being "pulled in" from above. Example from this same
session: `pivotTable.Warm.columnHeaders` repeats `bold`/`autoSizeColumnWidth`/
`columnAdjustment`/`titleAlignment` from `pivotTable.*.columnHeaders`, adding
its own `alignment: 'Right'`/`defaultColumnWidth: 100` on top — if the preset
had declared only `alignment`/`defaultColumnWidth`, visuals on the `Warm` preset
would have lost the bold/autoSize/fixedWidth headers obtained from anywhere but
`<type>.*` (the preset ignores it completely as soon as it mentions the same
key).
