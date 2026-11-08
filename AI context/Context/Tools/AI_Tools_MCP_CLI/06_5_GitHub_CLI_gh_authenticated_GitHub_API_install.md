Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## 5. GitHub CLI (`gh`) — authenticated GitHub API (installed 2026-10-15)

- `winget install --id GitHub.cli` → 2.102.0, signed in as `AyratGabdrakhmanov`
  (`gh auth login --web`, token in the Windows keyring, scopes `gist`, `read:org`, `repo`).
- Why: anonymous GitHub API = 60 requests/hour per IP (used up by a few schema checks);
  `gh api ...` = 5 000/hour. Used by `UpdateSchemas.ps1` to list schema versions. Raw file
  downloads (`raw.githubusercontent.com`) are not rate-limited and need no token.
- A shell opened before the install may not see `gh` on PATH — full path
  `C:\Program Files\GitHub CLI\gh.exe`.
