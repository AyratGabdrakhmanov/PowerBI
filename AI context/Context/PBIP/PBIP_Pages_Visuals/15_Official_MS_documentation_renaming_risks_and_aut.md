Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️⚠️ Official MS documentation: renaming risks and auto-removal of invalid references from bookmarks

Verified against the official Microsoft documentation — [Power BI Desktop project
report folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report)
(sections "PBIR naming convention" and "Common PBIR errors"), 2026-09-09.
Confirms and complements everything found empirically in this session.

**MS's official position on renaming (verbatim):**
> "Renaming the 'name' property within each JSON file is supported but
> **might break external references both inside and outside the report**."

**Allowed characters in an object/file/folder name per the documentation** — broader
than our ASCII-only rule: "word characters (letters, digits,
underscores) or hyphens" — i.e. letters of **any
language** (not only ASCII) are formally allowed, not just Latin letters/digits. **This does not cancel**
our narrowing to pure ASCII in `Get-SafeName` — that rule applies at the
level of **another**, stricter mechanism (Part URI validation on
Publish/Export Template, see below), not at the level of the PBIR format itself.
Two different rules at two different levels: PBIR as a format allows more,
but packaging into an OPC container for Publish/export requires less — ASCII-only
is safe for both at once, so it remains the right choice.

**The "silent failure" on an invalid name is confirmed (we already knew it empirically,
now officially confirmed):**
> "After rename visual or page folder names, my visual or page no longer
> appears when opening the report." → "If it doesn't comply with the
> naming convention, Power BI Desktop **ignores the file, or folder** and
> treats it as private user files."

**⚠️⚠️ New and important — Power BI Desktop ITSELF removes invalid references from
bookmarks on the next save in the UI, without warning:**
> "I copied a bookmark file, and upon saving, most of the bookmark
> configuration was deleted." → "report bookmarks capture the state of a
> report page along with all its visuals... any **invalid visuals are
> removed from the bookmark configuration**" — documented as
> *intended* behavior (not a Desktop bug); happens automatically on
> any save, not only when copying a bookmark between reports.

**Practical consequence:** if a bookmark still has a reference to a visual
that became invalid due to a renaming bug (for example, our
"chained substitution" bug with `parentGroupName`/`visualContainers`) — and
the user then opens and saves the report in Power BI Desktop **before**
the reference is fixed — Desktop will **silently cut out** that part of the
bookmark configuration forever, without an error and with no way to tell it
apart from a deliberate user action after the fact. Hence the practical
rule: **check and fix all references in `bookmarks/*.bookmark.json`
RIGHT AFTER any mass renaming, before the user
opens the project in Desktop** — otherwise the damage can become irreversible not
through an error, but through Desktop's silent self-repair, which actually
means data loss.

**`mobile.json` (a visual's mobile layout) — checked, safe for
folder renaming.** The official schema
(`visualContainerMobileState`) — a separate file `visuals/<name>/mobile.json`
next to `visual.json` (this project has **39** such files). Its
content was checked — it stores only `position` (coordinates for the mobile layout),
and **does not contain** `"name"` or `parentGroupName`/any references to other
objects. Since it physically lives **inside the same visual folder**, when the
folder is renamed (two-phase rename in the script) it moves automatically
together with `visual.json` — no separate synchronization is needed;
`rename_pages.ps1` does not need to be extended for this file.

**`pageBinding.name` — not related to renaming pages/visuals, no need
to touch it.** An internal page ID (used for page-level Drillthrough/tooltips),
it must be **unique across the whole report** — per the
documentation, before June 2024 it was a short name (`"Pod5"`, `"Pod6"` — as
in this project, meaning the objects were created/re-saved before that date); after that —
a GUID by default. It never references a page/visual **by folder
name**, so it is outside the scope of `rename_pages.ps1` — there is no need
to touch it, and it should not be touched.

**References "outside the report" (beyond the PBIP project) cannot be
checked locally from files.** MS's official warning is explicitly broader
than what we can track by grepping the project files: renaming a
page/bookmark/visual can break pins on a Power BI Service dashboard,
subscriptions, deep links (Teams/Outlook/email), embedded links
to a specific page — anything addressed by the same identifier
from outside the report. If such external references exist, they must be re-checked
manually after mass renaming; the automation of local scripts fundamentally
cannot reach them.
