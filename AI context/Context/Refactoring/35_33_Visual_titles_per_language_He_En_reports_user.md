Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 33. Visual titles per language (He / En reports, user 2026-10-31)

Every **visible** visual title is a He / En measure, never literal text: one hidden measure per distinct text in
`_Measures`, folder `Labels`, named `Title <En text>`, pattern of the `Slicer *` titles (`COALESCE ( [Selected Culture],
USERCULTURE () )`, he-IL → Hebrew, else English, `-- <En>` comment); title `text` → `{ "Measure": ... }`. Scope: titles with
`show = true`, plus charts with no `show` (tables / matrices / cards / buttons / shapes have the title off by default).
Hidden literal titles are left. Fix obvious typos in the He text; English names of agents / families from
`CT_ValueTranslation` / `CT_AreaManager`. Diff first: proposal table (measure, He, En, visuals, pages) → user OK → apply.
Templates: ClientC `Slicer *`, ClientB Inventory Coverage `Title DQ Page`. ClientC script `Agency\ClientC\Refactoring\Step33_34_titles_headers.py`.
