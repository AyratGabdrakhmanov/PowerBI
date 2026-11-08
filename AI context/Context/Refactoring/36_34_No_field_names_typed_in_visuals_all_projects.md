Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 34. No field names typed in visuals (all projects, user 2026-10-31)

A field header / label in a visual is the model name (English; he-IL caption), never a name typed in the visual: remove
`displayName` from **every** projection — columns, hierarchy levels and measures (e.g. ClientC `ירון 3` `a0a34571db92f9c03984`:
`Items.Family` typed `סה"כ` → `Family`; `צוות ירון` `578598bdc68760a3fd24`: `[SalesValue]` typed `מכירות` → `SalesValue`).
A header that needs another wording or language gets it in the model (measure name, captions, FP rows per language — step 23),
not in the visual. Hebrew viewers must not see a change (user 2026-10-31): remove a typed name only when it equals the
he-IL caption, when the field has no caption (caption := typed name), or when the field is typed several ways (unify: one he-IL
caption; two objects of one table may share a caption — `Items[ItemGroup]` / `[ItemGroup Display]` both have it, the model
loads; the ClientC run 2026-10-31 still kept the current caption on such clashes). Context labels
(Period A / B) stay typed until they have their own model object. The removed texts are listed in the proposal file (input for captions / FP labels). Same proposal file
and script as step 33.
