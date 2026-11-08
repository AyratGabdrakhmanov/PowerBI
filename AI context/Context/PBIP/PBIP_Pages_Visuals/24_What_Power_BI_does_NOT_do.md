Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## What Power BI does NOT do

- ❌ Does NOT scan additional folders automatically
- ❌ Does NOT create folders by itself
- ❌ Does NOT update `pages.json` when renaming in the UI without re-saving the project
- ❌ Does NOT raise an explicit error for a missing page — it simply does not show it
  (a silent failure, not an exception)
- ❌ Does NOT work with pages if the folder name contains spaces
- ❌ Does NOT preserve JSON formatting — when opening/saving in the Power BI Desktop
  UI editor, the format may differ from what the script wrote (this is normal,
  the main thing is that it is valid and without a BOM)
- ❌ Slicer: `header` (auto-picks up the name of the field/column placed in the slicer)
  does NOT support text alignment — there is neither an `alignment` property in JSON nor
  a control in the Format pane (verified — adding `alignment` to
  `objects.header.properties` is not picked up). Alignment exists only on
  `Title` (`visualContainerObjects.title.properties.alignment`), but `Title` cannot
  automatically pull in the field name — only static text or a
  DAX measure that has to be maintained by hand when the field changes. "auto field name"
  and "alignment" are not available at the same time — you have to choose one of the two.
