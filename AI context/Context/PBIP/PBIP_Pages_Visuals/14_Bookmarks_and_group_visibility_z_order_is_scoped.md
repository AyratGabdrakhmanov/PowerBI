Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️ Bookmarks and group visibility — z-order is scoped WITHIN the parent group, not across the whole page

`bookmarks/*.bookmark.json` can toggle the visibility of an entire group via
`explorationState.sections.<page>.visualContainerGroups.<name>.isHidden`.
For such a toggle to have a visible effect (the group actually appears
"on top" of everything else when `isHidden: false`), two things matter at the same time:

1. **The group's own `position.z`** must be higher than that of the elements
   it overlaps on screen — but this comparison makes
   sense **only between visuals with the same parent** (a `ScaleMode`
   group creates its own local stacking context, like CSS `z-index` inside
   `position: relative`). Comparing the `z` of two visuals from DIFFERENT parent
   groups directly is meaningless — their actual drawing order depends on
   the `z` of their parents, not only their own.
2. **A correct `parentGroupName` chain all the way to the top** — if an element
   (or a whole subgroup) is accidentally nested in the wrong group (see the bug above), its
   effective drawing order changes, even if its own
   `position.z` is untouched: it now stacks relative to **other**
   neighbors, with a different final result on screen.

**Practical method for diagnosing "the bookmark has no visible effect":**
1. In the `.bookmark.json` file(s), find all keys under
   `visualContainerGroups`/`visualContainers` that actually toggle
   (`isHidden` changes in at least one of the bookmarks) — only these are
   relevant; the rest of the page tree can be left alone.
2. For each such node, compare with the backup: `position.z`, `parentGroupName`
   (and its `displayName`+`z`) — they must match 1-to-1.
3. If they match — go one level up the tree and check the **whole**
   parent chain (see the previous section about duplicate `displayName`),
   not just the immediate parent — the breakage can be at any
   level of the chain, not necessarily at the toggled node itself.
4. If the chain is clean too — the problem is most likely not in the data, and
   a visual check in Power BI Desktop (screenshot) is needed — automation based on a single
   backup cannot resolve the situation any further.
