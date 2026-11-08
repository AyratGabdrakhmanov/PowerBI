Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `CheckTooltipFit.py` (2026-10-30)
`python -X utf8 Scripts\CheckTooltipFit.py "<X.Report>" [--out <png folder>] [--pid <pid>] [--fill RRGGBB]` — screenshots every
tooltip page (`page.json` `type: Tooltip`) of the open report via the bridge, finds the box (rows / columns dominated by the
fill colour, default `[Blue Logo]` `#134591`) and the light text in it; `OVERFLOW` when the text is closer than 2 % to an
edge. Summary only. Run once per language. Refactoring step 24.
