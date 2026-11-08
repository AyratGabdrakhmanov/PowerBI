Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️ Promoting settings from the "named preset" level to the "visual type (`*`)" level

If a visual type (for example `cardVisual`) has only **one** preset, its
content can safely be "collapsed" into the base `visualStyles.<type>.*`: then the
style applies automatically to **all** visuals of this type in the report, even
those with no `stylePreset` set at all — and `stylePreset` in `visual.json`
can be removed as unnecessary.

**Important danger:** if the report already has **other** visuals of the same type
without an explicit preset (relying on the "clean" `visualStyles.<type>.*`, previously
empty or absent), they will **also** start inheriting everything moved
up there — including hidden test pages and any visuals of the same type on
visible pages. Before such a promotion, be sure to check:
```powershell
grep -rl '"cardVisual"' "Model_v2.Report/definition/pages" # all visual.json files with this type
```
and for each one found, check whether `stylePreset` is used there (if
not — it will be affected by the promotion).

If later you need to separate the "default" (`*`) behavior from a specific
instance, you can keep **in parallel** both `visualStyles.<type>.*` and
`visualStyles.<type>.<PresetName>` with identical (for now) content, restore
`stylePreset` in the relevant `visual.json`, and differentiate them precisely in the future.
