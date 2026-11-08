Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️⚠️ Three fields reference a PAGE by its folder name — and this was historically never tracked

At least **three different places** in `visual.json` store a reference to another
page by the same identifier as its folder name (the same principle as
`visualInteractions` above, only one level up — a page, not a visual):

**1. `visualLink.navigationSection`** — on an `actionButton` with the "Page
navigation" action, a reference to the target page:

```json
"visualLink": [
  {
    "properties": {
      "navigationSection": {
        "expr": { "Literal": { "Value": "'CollectorAssignment'" } }
      }
    }
  }
]
```

**2. `visualTooltip.section`** — on any visual with a custom report-page
tooltip ("Type: Report page" instead of the default), a reference to the page
used as the tooltip content:

```json
"visualTooltip": [
  {
    "properties": {
      "show": { "expr": { "Literal": { "Value": "true" } } },
      "section": {
        "expr": { "Literal": { "Value": "'TTCure'" } }
      }
    }
  }
]
```

**3. `visualLink.drillthroughSection`** — on an `actionButton` with the
"Drillthrough" action (not "Page navigation"), a reference to the target drillthrough page
(the one shown in the UI as the **Destination** field in the Action pane).
Such a button carries **both** `navigationSection` and
`drillthroughSection` — both fields are present side by side, but for the
`"Drillthrough"` type Power BI Desktop actually uses/resolves only
`drillthroughSection`; `navigationSection` in this case is a "stuck"
leftover (the last selected value from when the action type was/could
have been "Page navigation"), does not reflect the actual target and **is not suitable as a
source of truth** for restoring a broken reference (see below):

```json
"visualLink": [
  {
    "properties": {
      "navigationSection": { "expr": { "Literal": { "Value": "'Details1'" } } },
      "type": { "expr": { "Literal": { "Value": "'Drillthrough'" } } },
      "drillthroughSection": { "expr": { "Literal": { "Value": "'PTPDetalis'" } } }
    }
  }
]
```

**Discovered in practice (a serious bug found):** `rename_pages.ps1`
never updated any of these three fields when renaming pages —
not in this session nor, apparently, in earlier ones. Result: almost **all**
navigation buttons in the project at the time of checking referenced page hash IDs
(`fd374f016489acd16bbd`, `2a5c015454a6c03db1e1`, etc.) that have long ceased to
exist both in the current project and in the oldest available backup — that
is, the mapping "which hash is which page" is **irretrievably lost**; these
buttons silently did not work (Power BI does not raise an error for a non-existent
`navigationSection`/`section`/`drillthroughSection` — a silent failure, as with
other "missing" entities). `visualTooltip.section` at the time of
checking was still intact (`'Blank'`, `'TTCure'` — both pages exist),
but it is the same class of bug, just not yet triggered — on the next
renaming it would have broken in exactly the same way.

`drillthroughSection` was found separately and later (2026-09-15, project
Collector Assignment) — `navigationSection` was already being fixed by the script, which
is why the bug went unnoticed longer: by eye the button looked
"half fixed" (`navigationSection` = the current page name), but
the actual `Destination` in the Action pane remained empty, because it was
`drillthroughSection` that still pointed to a non-existent folder. 16 buttons in
Collector Assignment.Report were broken this way at the time of discovery.

**Script fix (done):** after renaming pages, the script
now goes through **all** `visual.json` files of **all** pages and, using `$renameMap`
(old name → new), precisely replaces the `Value` inside **all three** fields —
a non-greedy regex `(?s)"<key>"\s*:\s*\{.*?"Value"\s*:\s*"'OLD'"` (where `<key>` is
`navigationSection`, `section` or `drillthroughSection`), which matches
only ITS OWN nested `Value`, not any text literal in the file
that happens to match the old page name.

**Historically broken references cannot be restored automatically** — there is no
source to take the mapping from. You also **cannot** simply copy
the value of the neighboring `navigationSection` into a broken `drillthroughSection` (or
vice versa) — as shown above, these two fields on the same button of type
`"Drillthrough"` can legitimately point to DIFFERENT pages, and
`navigationSection` there does not reflect the actual target. The practical way out: in
Power BI Desktop open each such button/tooltip → Format → Action /
Tooltip → choose the right page again from the current list (it
shows the current real names, not hashes); when restoring in bulk —
go by the button label (text) and by which pages are actually
set up as valid drillthrough destinations (the `page.json` of such pages
contains `"pageBinding": { "type": "Drillthrough", ... }` — only they can
be the real target of `drillthroughSection`; other page folders can
be excluded as candidates right away).

**If a fourth such field appears** (something else referencing a page by
folder name) — add it to the same regex alternation `(?:navigationSection|section|drillthroughSection)`
inside `Rename-PageRefsOnce`, rather than writing a separate similar block of code.
