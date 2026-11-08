Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## DAX User-Defined Functions (`functions.tmdl`)

The model supports **DAX UDFs** (user-defined functions) — reusable
pieces of DAX defined once and called from any measure. They live in a
separate file `Model_v2.SemanticModel/definition/functions.tmdl`, which is
picked up automatically (like `relationships.tmdl`/`expressions.tmdl`) —
no `ref function` line in `model.tmdl` is required.

### Syntax

```
function 'Namespace.FunctionName' =
		(
		    paramName : TYPE,
		    ...
		) =>
		VAR ...
		RETURN ...
	lineageTag: <guid>
```

Called from a measure without quotes around the name (if it is a valid dotted
identifier): `Namespace.FunctionName ( arg1, arg2, ... )`.

### Parameter types

- **`EXPR`** — a lazily evaluated DAX expression (preserves the calling context,
  works correctly with CALCULATE/context transition inside the function).
  Use it for anything that should remain a *measure/expression* rather than
  a ready value — e.g. a base measure that the function itself wraps
  in `CALCULATE(...)` with different filters.
- **Reference types — `ANYREF` / `MEASUREREF` / `COLUMNREF` / `TABLEREF` / `CALENDARREF`**
  (always `EXPR`, the keyword can be omitted). They keep the reference, so `NAMEOF ( param )` /
  `TABLEOF ( param )` work inside the body; with a plain `EXPR` parameter `NAMEOF` fails ("Only
  measure or fully-qualified column or table or calendar references are allowed", checked
  2026-10-22). **Use the most specific one** (SQLBI, "Understanding parameter types in DAX UDF"):
  `MEASUREREF` accepts only a model measure (an expression fails: "Expected 'MEASUREREF' but got
  'SCALAR'") and always does a context transition — no `CALCULATE` needed; `ANYREF` accepts any
  expression, so wrap it in `CALCULATE` when a transition is needed. Name suffixes: `Measure`,
  `Column`, `Table`, `Calendar`, `Expr`. Example: `Collection.PickOverviewMetric ( metricMeasure :
  MEASUREREF )` — `PBIP_Recipes.md` → "Recipe: drill from a matrix cell to the rows behind it".
- **`STRING` / `INT64` / `DOUBLE` / `BOOLEAN` / ...** — ordinary scalar types,
  for parameters that always come in as a literal constant (a mode flag,
  a number). Use them instead of `EXPR` when the parameter does not have to be
  a lazy expression — this simplifies the signature and makes the intent explicit.

⚠️ DAX evaluates variables inside the function body **lazily** — a `VAR`
that nothing references in the chosen `IF` branch is not evaluated at all.
This is actively used in `Collection.FormatRefLabel` (see below): some of the
six `CALCULATE` calls for time intelligence are not executed if they are not actually
needed for the given `rowType`.

### `Collection.FormatRefLabel` — formatting the prior-period comparison string

A shared function for all cards with a `referenceLabel` (see the recipe below).
Signature:

```
(
    rowType :     STRING,   -- "Row3" (number + Δ ABS + Δ %) or "Row2" (number + Δ pp, no %)
    periodType :  STRING,   -- "Month" or "Year"
    baseMeasure : EXPR,     -- the base measure [X] itself, no wrappers
    fixTotal :    INT64     -- budget of spaces (UNICHAR 8199) before "Δ: ", tuned by eye to the card width
) => ...
```

Inside, the function itself calls all the time-intelligence arithmetic via
`'CG Time Intelligence'[TimeIntelligence]` (`PMTD`/`PY`/`MOM`/`YOY`/`MOM %`/
`YOY %`) and swaps the "current"/"opposite" period
depending on `periodType`, formats both (SWITCH thresholds bn/M/K for
`Row3`, `pp` format for `Row2`) and aligns the columns with monospaced spaces
(`UNICHAR(8199)`), so that the values in the Month and Year rows of one card
visually match in column width.

The call from a measure is now literally one line:

```
measure 'X Change Month' =
    Collection.FormatRefLabel ( "Row3", "Month", [X], 11 )

measure 'X Change Year' =
    Collection.FormatRefLabel ( "Row3", "Year", [X], 11 )
```

For cards with a percentage base measure (`X` is already in `%`) — `rowType = "Row2"`
(no `Δ %` column, since a "change of the percentage change" is usually not needed).

⚠️ There is **no need** to create separate measures `X Prev MTD`/`X PY`/`X MOM`/`X YOY`/`X MOM %`/
`X YOY %` for a new card — all the time-intelligence
logic is now inside the function. (Older versions of this file described the
opposite pattern — 6 wrapper measures per card; they were deleted as
unused code after the switch to UDFs.)

### `///` doc-comment — the function's "Description" field (TOM), not `description:`

A DAX UDF has no TMDL property `description:` — what Power BI Desktop
shows as the function description in Model Explorer (TOM `Function.Description`)
is, on disk, a **doc-comment** `///` directly ABOVE the line `function 'Name' = ...`
(indent 0, the same level as `function`/`table`/`queryGroup` itself —
the same technique is already used in `model.tmdl` for `queryGroup MarketDealer`).
It supports the tags `@param {Type} name - description` and `@returns description`:

```tmdl
/// Short one-line description of the function.
/// @param {STRING} paramName - what it is
/// @returns what it returns
function 'Namespace.FunctionName' = ```
		...
		```
	lineageTag: <guid>
```

Source: [Microsoft Learn — Using DAX user-defined functions](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-user-defined-functions-overview)
(verified 2026-09-15 before editing, so as not to break model loading
with wrong syntax — see the `description:` myths below).

⚠️ Nothing like `description:` as a separate TMDL property of a function
exists — if you see it in an old draft/note, do not trust it;
use `///` above the declaration.

### ⚠️ 2026-09-15 — 100%/-100% formatting fix + doc-comment + inline comments

`Collection.FormatRefLabel` (the Row2 branch, `__FormatPreviousPeriod`/
`__FormatPreviousPeriod2`) used to always show one decimal place
(`"#,0.0%;-#,0.0%;0%"`) even for exactly 100%/-100% (`"100.0%"` instead of `"100%"`).
Added: `__DefaultFormatRow2ValueLevelWhole = "#,0%;-#,0%;0%"` and the check
`ROUND ( __PreviousPeriod[2] * 100, 1 ) IN { 100, -100 }` — on a match
the integer format is used instead of the one-decimal format,
via `SWITCH ( TRUE() ... )` (not a nested `IF(IF())`, per Best Practice).
We considered applying the same to `__FormatPeriodOverPeriodPercent`
(the delta percentage) — not needed, it is always an integer anyway
(`"+#,0%;-#,0%;0%"`, the format has no decimal places at all).

Along the way — a `///` doc-comment was added (description + `@param`/`@returns`, see
above) and inline `--` comments on all non-trivial blocks of the function
(why the "2"-suffixed VARs are needed — they are NOT the same value for another
row on the display, but purely for measuring the text width of the other
row of the card for alignment; where `fixTotal` comes from; how the
`UNICHAR(8199)` padding works). The function's behavior itself did not change — only
the explanations.

**Tested first on one copy (`ClientA\Model\Model_v2.SemanticModel`),
explicitly requested by the user ("test then apply") — only after
confirming that the model opens and `100%`/`-100%` are shown without
decimals was it applied to all 4 copies.**

**Found along the way: `Collection.FormatRefLabel`/`LoanData.
RemoveFurtherRelationships` in `functions.tmdl` are identical (byte for byte) in
FOUR copies of the project** — `ClientA\Model\Model_v2.SemanticModel`,
`ClientA\Collector Assignment\Collector Assignment.SemanticModel`,
`ClientA\Collateral workflow\Model_v2.SemanticModel`, `ClientA\Journal Entries\
Journal Entries.SemanticModel`. As with `Find-UnusedMeasures.ps1`/
`Replace-ModelTable.ps1` earlier — an edit in one copy does NOT imply the
others automatically; the user clarifies/confirms each time
(see `ClientA\CLAUDE.md`, which also has the current list of all known copies and their
current paths — `Collector Assignment\` moved from `Collector
Assignment\Report\` on the same day, 2026-09-15).

### Working with `functions.tmdl`/`Measure.tmdl` — the same CRLF gotcha as everywhere in TMDL

Both files are stored in **CRLF**. Any edit via a text Edit tool
inserts a bare `\n` for the changed part — after **every** edit
you must run the normalization and check the balance of triple backticks:

```js
const fs = require('fs');
for (const path of [
  'Model_v2.SemanticModel/definition/tables/Measure.tmdl',
  'Model_v2.SemanticModel/definition/functions.tmdl',
]) {
  let content = fs.readFileSync(path, 'utf8');
  content = content.replace(/\r\n/g, '\n').replace(/\n/g, '\r\n');
  fs.writeFileSync(path, content, 'utf8');
  console.log(path, 'bad LF:', (content.match(/[^\r]\n/g) || []).length,
    'fence parity ok:', (content.match(/```/g) || []).length % 2 === 0);
}
```

### TMDL gotcha: `formatStringDefinition` (dynamic format string) goes LAST (2026-10-30)
`formatStringDefinition = …` is a **child object** of the measure: it must come after the measure's properties
(`displayFolder`, `lineageTag`, `isHidden` …). Placed before them, Desktop refuses the whole PBIP: "TMDL Format Error —
Invalid indentation was detected" at the next property line, and opens an empty Untitled window (ClientB Inventory Coverage,
`Coverage Months` "24+"). Needs compatibility level ≥ 1601.
**And no static `formatString` next to it** (ClientC 2026-11-05, 4 achievement measures): with both, Desktop refuses the PBIP
("has both FormatString property and FormatStringDefinition property defined") → empty Untitled window. Adding a dynamic
format to a measure = delete its `formatString:` line, put the old format as the default branch of the expression
(`IF ( ABS ( SELECTEDMEASURE () ) >= 1, """>100%""", "0%;-0%;0%" )`), expression last after an empty line. ⚠️ MCP
`ConnectFolder` loads such TMDL without error (it catches the indentation error, not this one) — only Desktop / engine
reports it. Script with both rules: `ClientC\Sales New\Refactoring\Achievement_FormatString.py`. Read this section before
any `formatStringDefinition` edit.

### Time-intelligence UDFs `TI.*`
Rules, catalog, apply / check: `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Context\PBIP\TI_UDF.md`.
