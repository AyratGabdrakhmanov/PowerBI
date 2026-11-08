Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 10. Agent / team dimension (ClientC only — no such requirement in ClientB, user 2026-10-26)

One agent dimension (report name, SAP code, Team, Manager, Active) instead of team name lists in page / visual filters;
pages filter the Manager / Team field, so a new agent appears by itself. Target: SAP user fields on `OSLP`; until then
a DAX table (ClientC: extend `CT_CardAgents`).
