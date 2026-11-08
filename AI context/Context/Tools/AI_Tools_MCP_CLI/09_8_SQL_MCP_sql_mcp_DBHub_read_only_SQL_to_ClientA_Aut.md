Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## 8. SQL MCP `sql-mcp` — DBHub, read-only SQL to ClientA ClientA-DB (set up 2026-11-06)

User decision 2026-11-06: Claude may query ClientA / ClientA-Project **ClientA-DB** directly, **read-only** (all other
clients stay RDP-only — `Infrastructure.md` → "SQL access from this workstation").

- **Server:** [DBHub](https://github.com/bytebase/dbhub) (`@bytebase/dbhub`, open source, Bytebase) — an MCP server for
  SQL databases; tool `execute_sql`. Pinned **1.5.0** (released 2026-10-09; 1.5.1 of 2026-11-03 was too fresh).
  Needs Node (`npx`, v24 here).
- **Target:** `SQL-Server-1` / `ClientA-DB` (SQL Server 2022, 16.0) — the PAC **dev** server, reachable only with the
  **VPN** VPN up. Login `powerbi` (SQL authentication; Windows integrated auth fails — "Cannot generate SSPI
  context", this workstation is not in PAC's domain). `pac-ClientA-DB02,2471` (the production name in Power Query) does
  not resolve from here. The login has **no VIEW DEFINITION** — view / procedure texts come back NULL.
- **Files:** scripts in `ClientA\_Documentation\Scripts\` (no secrets): `Set-DbHubLogin.ps1` — one-time window for login +
  password (never the console), password saved **DPAPI-encrypted** (only this Windows user on this PC can decrypt) to
  `%USERPROFILE%\.dbhub\pac.pwd`, config `%USERPROFILE%\.dbhub\pac.toml` (DSN with `sslmode=require`,
  `password = "${sql_mcp_PASSWORD}"`, `query_timeout = 300`, `[[tools]] execute_sql readonly = true, max_rows = 5000`);
  `Start-DbHub.ps1` — decrypts the password into the process environment and runs
  `npx -y @bytebase/dbhub@1.5.0 --transport stdio --config pac.toml`. Re-run `Set-DbHubLogin.ps1` to change the login.
- **Claude config:** `~/.claude.json` → `mcpServers.sql-mcp` = `powershell -NoProfile -ExecutionPolicy Bypass -File
  <...>\Start-DbHub.ps1` (added by script — no `claude` CLI on this PC; backup `~/.claude.json.bak_<timestamp>`).
  Tools appear after the next session start (Reload Window).
- **Status 2026-11-06:** the SQL login was checked (`SELECT @@SERVERNAME` → SQL-Server-1 / powerbi / ClientA-DB). The
  DBHub start through the wrapper and its read-only guard were **not yet tested** (the test was stopped) — first use:
  `SELECT 1`, then a harmless write (`UPDATE … WHERE 1 = 0`) must be refused.
- Fallback without MCP (2026-11-07): `Scripts\PacSqlQuery.ps1 -QueryFile <file.sql>` - same login, password from the
  DPAPI file, read-only guard, TSV out. `SqlQuery.ps1` (integrated auth) does not work for PAC.
- **Status 2026-11-07:** `sql-mcp` failed to start in two sessions ("Connection closed" - the VPN was not up at session
  start; it starts only with the session, Reload Window after connecting). The VPN also dropped twice during the day
  ("DNS name does not exist" for SQL-Server-1 while the VPN adapter showed Up) - reconnect VPN.
  The `powerbi` login has **no DDL** (CREATE SCHEMA / VIEW / PROCEDURE denied) - requested from ClientA in Azure #61.
