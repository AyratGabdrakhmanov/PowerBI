Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️ Key collision between the "object" and "container" levels inside a preset

Some property names exist **simultaneously** in two different schemas,
which a preset merges into a single flat structure:
- in the schema of the specific visual type (`visual-cardVisual`, etc.) — as a
  property of the visual itself;
- in `commonCards` — as a property of the container around the visual.

For `cardVisual` at least these overlap: `border`, `divider`, `general`,
`padding`, `spacing`. Since in the preset JSON both meanings sit under **one and
the same key**, moving both into the preset at the same time is impossible without losing
one of them — they are physically indistinguishable after merging.

**Decision adopted in this project:** for such pairs, keep the object
(specific to visual) level **entirely local** in `visual.json`, moving
only the container (commonCards) variant into the preset — even if in a particular
case the field names inside barely overlap and in theory one could
carefully separate them by hand. This makes it easier to keep things uniform and avoids the risk of
silently losing a value at the next edit.
