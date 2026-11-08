Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️⚠️ Key card property: `objects.padding` (`paddingUniform: 0`, `paddingIndividual: false`)

For cards on the `CardWithReference` preset (type `cardVisual`) this property is a
**mandatory local override** in `visual.json`, without which the card
is formatted incorrectly (found experimentally on "Collector #";
it gets lost/shifts when Power BI Desktop re-saves, and was once accidentally
removed while cleaning up "redundant" properties):

```json
"objects": {
  "padding": [
    {
      "properties": {
        "paddingUniform": { "expr": { "Literal": { "Value": "0L" } } },
        "paddingIndividual": { "expr": { "Literal": { "Value": "false" } } }
      },
      "selector": { "id": "default" }
    }
  ]
}
```

This is the **container** (`commonCards`) `padding` — not to be confused with the **object**
`padding` (`top`/`bottom`/`left`/`right`), which lives in the theme
(`visualStyles.cardVisual.*`/`CardWithReference`, see the key collision above) and
controls the inner padding of the callout area (currently `top: 5, bottom: 5`).
Both are needed at the same time and are not interchangeable — if a card looks
wrong (shifted positioning of text/value), first of all
check both of these `padding`s separately, not just one of them.
