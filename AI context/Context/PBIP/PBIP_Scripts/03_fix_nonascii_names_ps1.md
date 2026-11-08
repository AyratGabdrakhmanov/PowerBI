Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `fix_nonascii_names.ps1`
File: [`ClientA\_Documentation\Scripts\fix_nonascii_names.ps1`](<../../../Scripts/fix_nonascii_names.ps1>).
A one-off migration (not for regular runs — `rename_pages.ps1` itself
prevents new non-ASCII names from appearing, see "⚠️⚠️ Non-ASCII folder name
of a page/visual breaks Publish/template export" above). Scans all
pages and visuals whose folder name contains non-ASCII characters and
renames them to a hex ID (`577c6991bc39d800dd20` — the same style that
Desktop itself uses for new objects), syncing `page.json`/
`visual.json` `"name"`, `pages.json`, `navigationSection`/`section`,
`visualInteractions`, `parentGroupName` and bookmarks — i.e. the same set of
references that `rename_pages.ps1` fixes. It does not touch `displayName`/title text
— everything in the UI stays as it was. Run it once on a
project where non-ASCII folder names have already accumulated (for example, a report localized
into Hebrew/Cyrillic before this fix); after that `rename_pages.ps1` itself
keeps things clean.
