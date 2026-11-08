Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 46. Panel slicers span the colored filter panel (⚠️ RULE, all projects, user 2026-11-05)

Every slicer (incl. button slicers) in the right panel of the step-37 background has exactly the x and width of the
colored panel, no margin (1280 page: panel x 1080–1280 → slicer x 1080, width 200; 1920 page: x 1620, width 300). Replaces the panel width of step 37 for slicers; the ⓘ icon / small buttons keep their size. Heights and the stack
order stay. Script `ClientC\Sales New\Refactoring\Step46_PanelSlicerWidth.py` (scales with the page width). Check: script
lists 0 panel slicers off x / width, screenshot. ClientC `Sales NEW` ✅ 2026-11-05 (170 slicers x 1080 / w 200; 13 narrow 101 px ones widened).
