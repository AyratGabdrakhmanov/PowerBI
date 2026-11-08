Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 19. No shadows (all projects, user 2026-10-28)

Every visual: shadow off. PBIR `visual.json` → `visualContainerObjects.dropShadow[0].properties.show =
{ "expr": { "Literal": { "Value": "false" } } }` (set it on visuals that have `dropShadow` on; keep the other shadow
properties or drop them); also visuals in groups and on tooltip / hidden pages. Theme: `visualStyles.*.*.dropShadow`
`show: false` if the custom theme turns shadows on, so new visuals start without one. Check: script count of
`dropShadow show = true` = 0, `pbir validate`, screenshots.
