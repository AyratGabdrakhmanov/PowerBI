Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## Targeted property override within a single preset, without touching the shared level

If a property (for example `padding`) is currently **inherited** by a named
preset from the base `<type>.*` (the preset does not mention it at all), and you need
to change it **only for this preset**, without affecting the other visuals
of the same type without a preset or with a different preset — the solution: explicitly set
this property **inside the preset itself** with the required value, leaving the base
level as is.

Example: `padding.top/bottom` lived in `actionButton.*` (shared, `top: 5`), and
the preset buttons `GreyShadeActive`/`GreyShadeInactive` did not mention it
(they inherited 5). Some of the buttons (Tab1-15, plain `actionButton`) sit on
this same base WITHOUT the GreyShade preset — the shared level must not be touched. The solution was to
add `padding: {top: 0, bottom: 0, left: 0, right: 0}` **directly
into both GreyShade presets**, leaving `actionButton.*` untouched. This is a special
case of the general rule "move up to the shared level only when it does not
create contradictions" — here it is the opposite: you need to **go down** to the preset level
precisely because the shared level is used by other visuals unrelated to this
change.
