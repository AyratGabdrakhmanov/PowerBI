Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 44. Power BI options (⚠️ RULE, all projects, user 2026-10-14 / 2026-11-03)

Every report meets `PowerBI_Options.md` (the single source): Auto date/time OFF (`__PBI_TimeIntelligenceEnabled = 0`,
no `LocalDateTable_*` / `DateTableTemplate_*`), Q&A OFF (`definition.pbism` `settings.qnaEnabled: false`), Model view
Cards all ON (`diagramLayout.json`), native query approval OFF (machine setting, the user ticks it). File checks are
safe on closed files; an option changed in Desktop needs a restart. First step of phase A (no dependencies).
Check: script — the 3 file settings above per model. ClientB: ✅ 2026-11-03 (`Sales_ClientB` already compliant;
`Inventory Coverage` Q&A turned off).
