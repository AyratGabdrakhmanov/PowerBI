Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## What happens when you click "Style preset" in the Format pane

Verified experimentally: if you select a named preset for a visual from the drop-down
list, Power BI Desktop:
1. Writes the reference `visualContainerObjects.stylePreset.name = '<PresetName>'`
2. **Erases** the local values of all properties covered by the preset — leaving
   an empty skeleton (`{"properties": {}, "selector": {"id": "default"}}` etc. for
   each state), just so that the selector structure is preserved
3. Leaves as is only what the preset does **not** cover (the button's unique text,
   `navigationSection` — the navigation target page, etc.)

These empty `{"properties": {}}` are neither an error nor junk; they are harmless (they don't override
anything), but they can safely be removed to keep the file clean — rendering will not change.
