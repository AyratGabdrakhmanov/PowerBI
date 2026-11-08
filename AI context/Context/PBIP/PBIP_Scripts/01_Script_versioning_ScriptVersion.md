Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## Script versioning (`$ScriptVersion`)

`rename_pages.ps1`/`RenameObjects.ps1` prints a line like
`rename_pages.ps1 version 2026-09-15.1` at startup — the value lives in the constant
`$ScriptVersion` at the very top of the file. Purpose: this script is copied
between projects (Sales, Collector Assignment, master copy in
`_Documentation\`) — the version lets you tell a fresh copy at a glance from an
old one accidentally left behind (for example, forgotten in another folder before an
important fix was applied). **Rule: on any change to the script's logic — bump
`$ScriptVersion`** (date + a sequential suffix within the day, `YYYY-MM-DD.N`) and
sync the copy with the master version in `_Documentation\`.

**Change log in every script** (user, 2026-10-27): the header comment ends with `Change log:` — one line per change,
newest first: `YYYY-MM-DD.N  what changed and why` (`.N` = the `$ScriptVersion` / version suffix). Add the line with the change.
