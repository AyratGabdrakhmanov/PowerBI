Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md).

## 9. DAX Lib MCP (`daxlib`) — daxlib.org UDF packages (installed 2026-11-07)

- SQLBI's `@daxlib/mcp` 0.2.0 (repo `daxlib/daxlib-mcp`, MIT; library sources `daxlib/daxlib`, MIT).
  Announcement: SQLBI blog 2026-10-22. No telemetry, it calls only the DAX Lib API.
- Config: user-level `~/.claude.json` → `mcpServers.daxlib`:
  `cmd /c npx -y @daxlib/mcp@0.2.0 --start` (pinned; bump the version on purpose).
  Backup before the edit: `~/.claude.json.bak_daxlib`. Picked up at session start (Reload Window).
- Tools: `search_packages`, `get_package`, `get_package_readme`, `get_function_definitions`
  (UDFs as a `DEFINE` block for a DAX query, read-only), `list_local_instances`, `install_package`.
- Smoke test 2026-11-07: initialize + `tools/list` + `list_local_instances` OK (0 Desktop instances open).
- ⚠️ `install_package` writes into the open Desktop model and **replaces** UDFs with the same name
  (our `TI.*` from DAX PRO `TI_UDF.tmdl`) — test copies only; on real reports use
  `get_function_definitions` and add the code ourselves.
- Needs model compatibility level ≥ 1702; the server does not raise it.
- Gotchas: the `claude` CLI is not on PATH here, so `claude mcp add` fails — add the server by editing
  `~/.claude.json` with a node script (back it up first). For a manual stdio test, pipe requests through a
  node `child_process` script: PowerShell `-RedirectStandardInput` closes stdin at once and the server
  shuts down before it answers.
