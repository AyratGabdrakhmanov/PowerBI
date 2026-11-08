Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## Example: Collateral, 2026-10-06

`CollateralAction[RepoType]` → `RepoTypeGroup`, `VollyToInvoluntary` →
`RepoType` (together with `SourceColumn`), three measures `Involuntary/Voluntary/
Impound Repo #` switched to `RepoTypeGroup` — three `SaveChanges()`,
checked with a query, the measure values did not change. The Overview visual
(`4151717ef4d21fda05b6`) broke after that (it referenced
`RepoType`/`VollyToInvoluntary`) — fixed directly in the folder: `visual.json`,
`CollateralAction.tmdl`, `Measure.tmdl` (order above).
