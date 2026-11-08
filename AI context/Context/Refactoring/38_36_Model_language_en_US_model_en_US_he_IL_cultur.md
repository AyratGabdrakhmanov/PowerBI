Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 36. Model language: en-US model + en-US / he-IL cultures (⚠️ RULE, all projects, user 2026-11-01)

Every model: `culture: en-US` in `model.tmdl`, and two cultures `cultures/en-US.tmdl` + `cultures/he-IL.tmdl`. Object
names are English (steps 3 / 32, BPA `BP_MEASURE_NAMES_ENGLISH`); Hebrew is a he-IL caption, never the object name. A model
with only en-US (e.g. ClientF `Sales.pbip`) gets the he-IL culture (TOM `Model.Cultures.Add`, or a `cultures/he-IL.tmdl`
file + `ref cultureInfo he-IL` in `model.tmdl` on closed files); then the Hebrew names become he-IL captions (step 3).
Needs compatibility level ≥ 1400 for translations; the per-viewer display columns of step 9 need ≥ 1705. Check: BPA
`BP_MODEL_CULTURES_EN_HE`. Reference: Sales Channels / Sales v2 (en-US + he-IL).
