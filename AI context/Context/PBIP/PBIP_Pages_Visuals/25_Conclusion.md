Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## Conclusion

**The main rule:** the folder name, the reference in `pages.json` and the `name` field in `page.json`
must be identical **and must not contain spaces**. `displayName` is the only
place where spaces are allowed and even needed for UI readability. Following this,
plus UTF-8 without BOM and correct JSON indentation (via rebuilding by depth,
not regex), gives a stable PBIP project.
