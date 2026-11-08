Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `ReportFilters.py` — why is a page / visual blank (added 2026-11-01)

`python -I -X utf8 Scripts\ReportFilters.py "<X.Report>" [--pages "Page A,Page B"] [--field <text>] [--all-visuals]` —
read-only list of report-, page- and visual-level filters with their condition (`IN`, `NOT (= 0)`, `>` …, `[hidden]`).
`--pages` = display names or folder ids; `--field` = substring of `Table[Column]`; `--all-visuals` also lists visuals without
filters and their fields. Use it before answering "the page is blank": hidden visual filters (team, family, `Targets ≠ 0`)
and page filters left from the last save are the usual cause (ClientC `Sales NEW` 2026-11-01: team pages filter
`CT_AreaManager[Area Manager_En]` = Yaron / Matanya, so a Yossi / Oded client shows nothing there).
