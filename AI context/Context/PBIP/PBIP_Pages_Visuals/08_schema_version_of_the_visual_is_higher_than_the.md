Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## `$schema` version of the visual is higher than the publicly released one

**Where to check for new versions:** `github.com/microsoft/json-schemas` →
`fabric/item/report/definition/<type>/` (folder list = published versions,
`CHANGELOG.md` = what changed). Quick check from Bash:
`curl -s https://api.github.com/repos/microsoft/json-schemas/contents/fabric/item/report/definition/visualContainer`
(folder names), raw files at
`https://raw.githubusercontent.com/microsoft/json-schemas/main/fabric/item/report/definition/<type>/<version>/schema.json`.
The `developer.microsoft.com/json-schemas/...` URL in `$schema` returns 404 — it is only an id.
Checked and installed automatically every day by `Scripts\UpdateSchemas.ps1`
(log `Context\PBIP\Schemas\SchemaUpdates.log`) — see AI_Tools_MCP_CLI.md → "Updating pbir's schemas".

**Re-checked 2026-10-15 — the public repository caught up:**

| Schema | Latest published | Released | Local copy |
|---|---|---|---|
| `visualContainer` | 2.12.0 | Aug 2026 | [visualContainerSchema-2.13.0.json](../Schemas/visualContainerSchema-2.13.0.json) |
| `visualConfiguration` (embedded) | 2.7.0 | Aug 2026 | [visualConfigurationSchema-2.8.0.json](../Schemas/visualConfigurationSchema-2.8.0.json) |
| `report` | 3.3.0 | May 2026 | — |
| `page` | 2.1.0 | Mar 2026 | [page-2.1.0.json](../Schemas/page-2.1.0.json) |
| `bookmark` | 2.1.0 | Mar 2026 | — |
| `filterConfiguration` | 1.3.0 | Mar 2026 | — |
| `formattingObjectDefinitions` | 1.5.0 | Mar 2026 | — |
| `semanticQuery` | 1.4.0 | Mar 2025 | — |

ClientB (2026-10-15): 273 visuals on `visualContainer` 2.12.0, 89 on **2.13.0** (written by the
current Desktop, not published yet) — the lag described below still happens, just by one version now.

`visualContainer` 2.10.0–2.12.0 change only the `$ref` to `visualConfiguration`
(2.3.0 → 2.5.0 → 2.6.0 → 2.7.0); the content is in `visualConfiguration`:
- 2.5.0 (Jun 2026) — `VisualHeader.showCopilotSummaryButton`;
- 2.6.0 (Jul 2026) — `Spacing.spaceAbovePlotArea` / `spaceAboveDivider` / `spaceAboveSubtitle`
  (title-area spacing — these are the "unexpected" `SCHEMA_ERROR`s `pbir validate` gives on
  `actionButton`, see AI_Tools_MCP_CLI.md) and `VisualTooltip.showTooltipFieldsOnly` /
  `showSentenceFormat` / `sentenceTemplate` / `showChartSpecificTooltips` / `showValuesInBold`;
- 2.7.0 (Aug 2026) — no structural change (SU08 schema identity).

⚠️ Scanning projections: a field is `Column` / `Measure` (`Expression.SourceRef.Entity` + `Property`) **or**
`HierarchyLevel` (`Expression.Hierarchy.Expression.SourceRef.Entity` + `Hierarchy` + `Level`) — e.g. a Year → Month
hierarchy in matrix columns. A scanner that reads only `Property` reports such a role as empty (ClientC 2026-10-30: page
`Summary` reported "no month" while its columns held `Calendar[_Year-Month Slicer]`).

Query projection fields (`visual.query.queryState.<role>.projections[]`, schema
`visualConfiguration`), official descriptions:
- `queryRef` — "A unique name for this field - unique per visual";
- `nativeQueryRef` — "Native reference name for this field - unique per visual, used for
  referencing fields in visual calculations";
- `displayName` — "An override for display name - by default it is the field name in the
  semantic model";
- `active` — "Is the field currently active in the visual - used as part of drill
  operations": marks the current drill level of a hierarchy. In a hierarchical **slicer** it
  does not affect expanding (all levels expand by the arrows) — ClientB "לקוח" slicers have
  `active: false` on `CardName` / `BP_Key` and expand normally (checked 2026-10-15);
- `hidden` — "Is the field visible in the visual - used as part of visual calculations".

**History (kept for context):** our `visual.json` files reference
`.../visualContainer/2.12.0/schema.json`. In Microsoft's public repository
(`github.com/microsoft/json-schemas`), at the time of checking, the latest
published version is **2.9.0** (folders 2.10.0–2.12.0 are missing, `404`).
Conclusion: `$schema` in Power BI Desktop files is the internal format version
of a specific product build; it can be ahead of what Microsoft has managed to
publish in the open repository. To check fields, it is acceptable to look at the
closest available published version (2.9.0), but do not expect a 100%
match — some fields may have been added later and be missing there.

**Re-checked 2026-09-19 (on the user's hint — the repository's `.github/`
folder):** `visualContainer` in the public repository still
stops at **2.9.0** (our local copy is the latest
published one), `page` — at **2.1.0** (same situation, our local copy
`page-2.1.0.json` is also the latest published one, although the project's `report.json`
references `page/2.3.1/schema.json` — a discrepancy of the same kind).
The repository CI (`.github/workflows/validate-fabric-schemas.yml` +
`tests/validate-fabric-schemas_test.py`) checks only: (1) all `$ref`s
resolve to existing files, (2) `$id` starts with
`https://developer.microsoft.com/json-schemas`, (3) `$schema` is a valid
JSON Schema draft reference. **There is no check for "version published
together with the feature release" or for old versions remaining unchanged** — that
is, the public repository lagging behind real Desktop builds (as
seen above) is not a process bug, but an expected consequence of the fact that publishing to the
open-source repository and releasing a feature in the product are not guaranteed
to be synchronous events.

**Useful find: each versioned folder has a `CHANGELOG.md`**
(for example
`fabric/item/report/definition/visualContainer/CHANGELOG.md`) — a line-by-line
history of what was added in each schema version, tied to the product feature.
Handy for quickly checking "since which Power BI version/release did
this property appear" instead of guessing from `$schema` in the file. For example (as
of the time of checking): `visualContainer` 2.9.0 — "Auto Expand Pivot
Table" (explains `columnHeaders.autoExpand`/`rowHeaders.autoExpand` in the
`visual-pivotTable` schema, see "Report theme and Style Presets" above), "Fixed Width";
2.3.0 — Table "Grow to fit" (explains the enum `columnAdjustment:
'growToFit'`/`'fitToContent'`/`'fixedWidth'`). The `page` CHANGELOG.md is shorter —
mostly version upgrades of dependent schemas (`filterConfiguration`,
`formattingObjectDefinitions`, `semanticQuery`); in 1.3.0 — the
optional field `type` was added "to resolve formatting persistence issues".

Worth noting from schema 2.9.0 (not documented before; unchanged in 2.12.0):
- `isHidden: boolean` — a visual can be marked hidden directly in `visual.json`
  (used as standard, e.g. on some of the `shape`/`Tab*` visuals in the project —
  not to be confused with a hidden *page*; this hides a specific visual).
- `visualGroup` — a formal mechanism for grouping several visuals into one
  container (mutually exclusive with `visual` at the same level: `oneOf`). Not
  used in the project yet.
- `annotations: [{name, value}]` — arbitrary key/value pairs for notes
  directly in `visual.json`. Not used, but could replace informal
  naming conventions for "test"/"obsolete" visuals.
- `position.angle` — support for rotating a visual. Not used.
