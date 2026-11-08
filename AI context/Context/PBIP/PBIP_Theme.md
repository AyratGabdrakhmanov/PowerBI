# PBIP: report theme and Style Presets

> Part of the PBIP knowledge base (split 2026-10-12). Table of contents and section map — [POWERBI_PBIP_STRUCTURE.md](POWERBI_PBIP_STRUCTURE.md).

## Report theme and Style Presets

> **Split into the folder `PBIP_Theme\` on 2026-11-06** — this file is the index, the content is in the files below (moved verbatim; an old reference "PBIP_Theme.md → <section>" finds the section by its title here). New content goes into the section file, a new section = a new file + a line here. Convention: `README.md` of this folder's parent.

## Sections

- [Where the theme lives](PBIP_Theme/01_Where_the_theme_lives.md) — 10 lines
- [⚠️ Three places in `report.json` reference the theme file by name — same as with pages/visuals](PBIP_Theme/02_Three_places_in_report_json_reference_the_theme.md) — 79 lines
- [Theme structure: three color levels](PBIP_Theme/03_Theme_structure_three_color_levels.md) — 33 lines
- [`colorOrThemeColor` vs `ThemeDataColor` — two different ways to reference a color](PBIP_Theme/04_colorOrThemeColor_vs_ThemeDataColor_two_differen.md) — 35 lines
- [`visualStyles` and Style Presets](PBIP_Theme/05_visualStyles_and_Style_Presets.md) — 35 lines
- [UI names vs JSON keys](PBIP_Theme/06_UI_names_vs_JSON_keys.md) — 33 lines
- [States (`default`/`hover`/`selected`) inside a preset](PBIP_Theme/07_States_default_hover_selected_inside_a_preset.md) — 8 lines
- [What happens when you click "Style preset" in the Format pane](PBIP_Theme/08_What_happens_when_you_click_Style_preset_in_the.md) — 14 lines
- [⚠️⚠️ Inheritance inside `visualStyles` — by the WHOLE array, not by `$id`](PBIP_Theme/09_Inheritance_inside_visualStyles_by_the_WHOLE_arr.md) — 49 lines
- [Style level hierarchy and precedence rule](PBIP_Theme/10_Style_level_hierarchy_and_precedence_rule.md) — 46 lines
- [⚠️ Promoting settings from the "named preset" level to the "visual type (`*`)" level](PBIP_Theme/11_Promoting_settings_from_the_named_preset_level_t.md) — 24 lines
- [⚠️⚠️ Key card property: `objects.padding` (`paddingUniform: 0`, `paddingIndividual: false`)](PBIP_Theme/12_Key_card_property_objects_padding_paddingUniform.md) — 30 lines
- [⚠️ Power BI Desktop can silently rewrite `visual.json` while the project is open](PBIP_Theme/13_Power_BI_Desktop_can_silently_rewrite_visual_jso.md) — 18 lines
- [⚠️ A theme fundamentally cannot reference measures (DAX)](PBIP_Theme/14_A_theme_fundamentally_cannot_reference_measures.md) — 11 lines
- [⚠️ Key collision between the "object" and "container" levels inside a preset](PBIP_Theme/15_Key_collision_between_the_object_and_container_l.md) — 20 lines
- [⚠️ `layout.alignment` in the theme accepts only `left`/`center`/`right` (not `middle`)](PBIP_Theme/16_layout_alignment_in_the_theme_accepts_only_left.md) — 12 lines
- [Targeted property override within a single preset, without touching the shared level](PBIP_Theme/17_Targeted_property_override_within_a_single_prese.md) — 20 lines
- [`GreyShadeInactive` default fill — opaque since 2026-10-16 (Collector Assignment)](PBIP_Theme/18_GreyShadeInactive_default_fill_opaque_since_2026.md) — 16 lines
- [`GreyShadeTabFirstActive` / `GreyShadeTabFirstInactive` — styles of the FIRST tab (2026-10-16)](PBIP_Theme/19_GreyShadeTabFirstActive_GreyShadeTabFirstInactiv.md) — 24 lines
- [Matrix total row color — `pivotTable` (Collector Assignment, 2026-10-16)](PBIP_Theme/20_Matrix_total_row_color_pivotTable_Collector_Assi.md) — 11 lines
- [`GreyShadeTabActive` / `GreyShadeTabInactive` — tab presets (Collector Assignment, 2026-10-16)](PBIP_Theme/21_GreyShadeTabActive_GreyShadeTabInactive_tab_pres.md) — 42 lines
- [How to tell what can safely be moved from a visual to a preset](PBIP_Theme/22_How_to_tell_what_can_safely_be_moved_from_a_visu.md) — 14 lines
- [⚠️ Step 2 must not be done "by eye" on a single visual — check against all "siblings" of the same type](PBIP_Theme/23_Step_2_must_not_be_done_by_eye_on_a_single_visua.md) — 45 lines
- [⚠️ `tableEx` and `pivotTable` — different sets of allowed keys in `visualStyles`, not interchangeable](PBIP_Theme/24_tableEx_and_pivotTable_different_sets_of_allowed.md) — 24 lines
- [Table `fill` properties (`backColor`, `gridHorizontalColor`, `outlineColor`, `fontColor`) support `ThemeDataColor`](PBIP_Theme/25_Table_fill_properties_backColor_gridHorizontalCo.md) — 11 lines
- [Safely trimming `dataColors`](PBIP_Theme/26_Safely_trimming_dataColors.md) — 22 lines
