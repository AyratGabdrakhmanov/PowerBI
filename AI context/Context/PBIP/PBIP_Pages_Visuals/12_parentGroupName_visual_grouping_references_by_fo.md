Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️⚠️ `parentGroupName` — visual grouping references by folder ID, and old script versions could silently corrupt it

`visualGroup`/`parentGroupName` is the grouping mechanism: a visual (a leaf or the
group container itself) specifies `"parentGroupName": "<parent folder name>"`,
forming a tree (several levels of groups nested inside groups are
normal). Like `visualInteractions`/`navigationSection`, this is a reference **by
folder name**, so mass-renaming visuals without updating
`parentGroupName` everywhere it matches the old name is the same class
of bug as with page navigation.

**A bug found in practice (2026-09) — "chained substitution".** Old
versions of `rename_pages.ps1` fixed such references with a loop like:
```powershell
foreach ($old in $map.Keys) { $text = $text -replace [regex]::Escape($old), $map[$old] }
```
This is **unsafe** if the spaces of old/new generic names
overlap (and for visuals without a title — `visual`, `visual2`, `shape3`,
etc. — this is almost always the case). Example of real corruption: `visual5`
is renamed to `visual3`, while *another*, unrelated visual is simultaneously
renamed from `visual3` to `shape2` — if the replacement `visual3→shape2`
runs in the loop AFTER the replacement `visual5→visual3`, it re-matches
the text that was just written (intended for visual5!) and silently
overwrites it to `shape2`. The reference now points to a completely different
object, without a single error in the log.

**Fix (done in the script):** replace the loop with a single pass of
`[regex]::Replace` with a `MatchEvaluator` closure that resolves each match
through the `$map` hash table **against the original, still untouched text**, exactly
once per match — regardless of key order:
```powershell
[regex]::Replace($text, '"([^"]*)"', {
    param($m)
    $key = $m.Groups[1].Value
    if ($map.ContainsKey($key)) { return '"' + $map[$key] + '"' }
    return $m.Value
})
```
This approach is applied everywhere the script fixes references using the
rename map: `parentGroupName`, `visualInteractions`,
`navigationSection`/`section`, bookmarks (`bookmarks/*.bookmark.json`).

**How to find already accumulated corruption (if the bug fired before the script
fix) — three complementary methods, by reliability:**
1. **By title (most reliable)** — match the visual in the backup and in the
   current version by `visualContainerObjects.title.text`/`objects.header.text`
   (this field survives any folder renaming), then compare the
   `displayName` of the parent group in both. Does not work for visuals without
   a title (decorative shapes, group containers) — their title is always
   empty.
2. **By content (fingerprint)** — serialize `visual.json` without the fields
   `name`/`$schema`/`position`(/`parentGroupName`) and compare backup↔current;
   **unreliable** if several visuals on a page have identical content
   (decorative repeated shapes, nearly identical cards) — in that
   case the method gives an ambiguous result, and it must be skipped
   (flag) rather than guessed.
3. **By tabOrder + displayName of the parent/grandparent** — for visuals without
   a title, when several candidate groups have the same
   `displayName` (see below about duplicates) — compare `position.tabOrder` and
   `displayName` one level up (the parent's parent) until a
   unique match is found.

⚠️⚠️ **The check must cover not only "leaf" visuals (cards,
shapes) but also the group containers themselves** (`visualGroup` without a title) —
earlier passes in this session checked only visible elements by
title and missed at least one case where it was a
group container (without a title) that had been moved under the wrong parent.
The group tree must be traversed in full, including nodes without `title`/`header`.

⚠️⚠️ **Duplicate `displayName` on DIFFERENT physical groups is a source of
ambiguity, not a bug in itself.** In the user's Power BI Desktop,
several independent groups on one page can have the same name
("Group 1", "Group 3", etc. — an automatically generated name, never
renamed manually). Automatic backup↔current matching by
`displayName` alone **does not work** in this situation — you need to either
go one level deeper in the tree (grandparent/great-grandparent), or look at `tabOrder`,
or (in the most stubborn cases) explicitly ask the user for a screenshot of the
Selection pane tree and compare visually rather than guess by heuristics.

⚠️⚠️ **Possible "loss" of one of two physical groups with the same
`displayName`** — in practice there was a case where the backup
had TWO different "Group1→Group2" pairs (both with the same names, but
different physical folder IDs and different roles — one top-level with a large `z`,
the other nested in a third group with `z=0`), while the current project had only
ONE such pair left, and both independent descendants (from different original chains)
ended up attached to it. **Before fixing `parentGroupName` on such a
descendant based on the backup — check whether the same
target group is already reused by another descendant with a DIFFERENT, structurally distinct path in the backup**
(compare the full parent chain up to the very top for BOTH descendants, not
just the nearest parent) — otherwise you may "fix" one path while breaking a neighboring,
already correctly working one that uses the same shared node. In such a
situation automation is powerless — you need to either restore the physically
lost second group as a new folder, or confirm with the user via
a screenshot that the current merging of paths is deliberate and is the final
intent (not a forgotten accident).
