Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## States (`default`/`hover`/`selected`) inside a preset

Property arrays such as `fill`/`outline`/`text` inside a preset support per-state
entries via `"$id": "default" | "hover" | "selected" | "disabled"` — works
identically to `selector.id` in `visual.json`. `$id` is **not required** (you can put
an entry without it — it will then apply unconditionally, as an "unselector" toggle, e.g.
`{"show": true}` to turn a property on globally regardless of state).
