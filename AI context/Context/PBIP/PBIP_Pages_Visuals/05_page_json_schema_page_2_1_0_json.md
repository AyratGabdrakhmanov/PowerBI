Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## `page.json` schema (`page-2.1.0.json`)

A local copy of the official JSON schema for `page.json`
(`_Documentation/Context/PBIP/Schemas/page-2.1.0.json`,
`$id: .../report/definition/page/2.1.0/schema.json`) — the same idea as with
`reportThemeSchema-2.159.json`/`visualContainerSchema-2.13.0.json` (see "Report
theme and Style Presets" above): keep the official list of allowed
fields at hand to check against, rather than guessing from files already
encountered in the project. The schema version (2.1.0) is lower than the `$schema` actually
referenced by the `page.json` files in the project (`.../page/2.3.1/schema.json`, see
`reportVersionAtImport.page` in `report.json`) — the same discrepancy
"internal format is ahead of the published schema" already noted for
`visual.json` (see "`$schema` version of the visual is higher..." below); the fields described
here are current, but new ones beyond this list may also have appeared.

### Top-level `page.json` fields — full list per the schema

Besides the already documented `name`/`displayName`/`displayOption`
("Three critical places to keep in sync" above), the schema describes:

- **`visibility`** — `"AlwaysVisible"` (default) | `"HiddenInViewMode"`.
  This is the JSON field written by the right-click item on the page tab
  **"Hide page"** in Power BI Desktop — what the project notes previously
  informally called a "hidden page" with respect to individual
  test/tooltip pages. Not to be confused with hiding an individual *visual*
  (`isHidden` in `visual.json`, see "`$schema` version of the visual is higher..." below) —
  different mechanisms at different levels.
- **`type`** — `"Drillthrough"` | `"Tooltip"` (optional). Per the schema, this is
  a separate, simpler field from `pageBinding` (see "Three fields reference a
  PAGE" above) — `pageBinding.type` (`BindingType`: `Default`/
  `Drillthrough`/`Tooltip`) holds the actual binding logic with parameters,
  while the top-level `type` looks like a declarative label of the same role. In the project
  files examined earlier, it was usually `pageBinding` that appeared — if
  you encounter a page with only `type` but no `pageBinding`, it is worth re-checking
  what that means in practice (the schema formally allows both independently).
- **`howCreated`** — `"Default"` | `"Copilot"` (page created by Copilot,
  for example via "Auto create the report"). Visuals and filters also have it
  (`filterConfig.filters[].howCreated`, seen in `report.json` with the
  value `"User"` — i.e. the values differ by context/schema
  version, not a single fixed enum for all contexts).
- **`annotations`** — the same `{name, value}` mechanism of arbitrary pairs
  as for visuals (see "Worth noting from schema 2.9.0" below) — only
  here at the level of the whole page, not an individual visual.
- **`autoPageGenerationConfig`** — metadata for pages generated
  via "Quick Explore"/"Auto create the report" (which fields were selected,
  `related`/`combination` layout, visuals already created). In this project
  all pages were created manually — not encountered, but if it turns up during
  further exploration of someone else's/a new project — it is now clear what it is, no
  need to guess again.

### `objects` (`PageFormattingObjects`) — full list of page formatting categories

The counterpart of a visual's `visualContainerObjects`, but for the page itself. Each
category is an array `[{selector?, properties}]`, as usual. Full list per
the schema (of those already encountered in the project, only
`displayArea`/`section` are documented — the rest below were not checked against real project
files, but it is now known what to look for):

| Category | What it configures | Properties (per the schema, without type descriptions — the schema itself does not detail them) |
|---|---|---|
| `pageInformation` | Page name/alt name for Q&A | `pageInformationName`, `pageInformationAltName`, `pageInformationQnaPodEnabled`, `pageInformationType` |
| `pageSize` | Explicit page size (an alternative to top-level `height`/`width`?) | `pageSizeTypes`, `pageSizeWidth`, `pageSizeHeight` |
| `background` | Page background | `color`, `image`, `transparency` |
| `displayArea` | Vertical alignment of content (see `verticalAlignment: 'Middle'` above) | `verticalAlignment` |
| `outspace` | Same as `background`, but for the area outside `outspacePane`? (the schema reuses the `Background` definition) | `color`, `image`, `transparency` |
| `outspacePane` | Filter pane for the whole page | `backgroundColor`, `transparency`, `foregroundColor`, `titleSize`, `searchTextSize`, `headerSize`, `fontFamily`, `border`, `borderColor`, `checkboxAndApplyColor`, `inputBoxColor`, `width` |
| `filterCard` | Appearance of an individual filter card in the pane (see `$id: "Available"/"Applied"` in the theme) | `backgroundColor`, `transparency`, `border`, `borderColor`, `foregroundColor`, `textSize`, `fontFamily`, `inputBoxColor` |
| `pageRefresh` | Automatic page refresh (Page refresh) | `show`, `refreshType`, `duration`, `dialogLauncher`, `measure`, `checkEvery` |
| `personalizeVisual` | "Personalize visuals" (perspectives for report readers) | `show`, `perspectiveRef`, `applyToAllPages` |

**Note:** `report.json` uses similar but not identical categories
at the level of the **whole report** — `objects.section`/`objects.outspacePane` (see
the `report.json` example at the start of the document) — the same category names do not
guarantee an identical set of properties between the page level and the report
level; when in doubt, check against `formattingObjectDefinitions`/the specific
schema of that level rather than carrying properties over by analogy.
