# Starts the read-only SQL MCP server (DBHub, stdio) for ClientA / ClientA-Project ClientA-DB - called by Claude Code
# (mcpServers.sql-mcp in ~/.claude.json). Decrypts the DPAPI password written by Set-DbHubLogin.ps1 into the
# process environment only; nothing is written to stdout except the MCP protocol of DBHub itself.
#
# Change log:
# 2026-11-06  (1) First version (DBHub 1.5.0 pinned - released 2026-10-09)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:USERPROFILE '.dbhub'
if (-not (Test-Path (Join-Path $dir 'pac.pwd'))) { [Console]::Error.WriteLine('pac.pwd missing - run Set-DbHubLogin.ps1 first'); exit 1 }
$sec = Get-Content (Join-Path $dir 'pac.pwd') | ConvertTo-SecureString
$env:sql_mcp_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
& npx.cmd -y '@bytebase/dbhub@1.5.0' --transport stdio --config (Join-Path $dir 'pac.toml')
exit $LASTEXITCODE
