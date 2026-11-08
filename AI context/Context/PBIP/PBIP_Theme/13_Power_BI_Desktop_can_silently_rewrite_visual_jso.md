Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️ Power BI Desktop can silently rewrite `visual.json` while the project is open

If Power BI Desktop is open while the theme file is being edited by hand
(for example, renaming or deleting a named preset), on the next
save in the UI it may rewrite the related `visual.json` files **on its own**:
- remove a `stylePreset` that references a preset no longer in the theme
  (expected and safe);
- **but also reset** neighboring container properties (for example,
  `visualContainerObjects.background` reduced to an empty
  `{"properties": {}}`), even if they were set via a binding to a measure rather than
  via the preset — this looks like unintended data loss on the part of
  Power BI Desktop, not a consequence of the theme edit.

**Practical takeaway:** after any theme edit, if the project is open in Power BI
Desktop and the user saves it there, always re-read
the affected `visual.json` files from disk and check whether anything has gone missing, rather than
trusting the content that was in context before the save.
