# IBCS v1.2 — Design Rules (Summary)

Source: `IBCS_v1-2.pdf` (International Business Communication Standards, v1.2, 2022).
Built directly from the original English text; wording follows the standard as closely as
possible. Rule codes (UN, SA, ST, EX, SI, CO, CH) match the standard. Items marked
*(figure)* are shown in the standard's figures but not stated in its text.
✅ = do, ❌ = don't. Full text and page images: `IBCS_v1-2\`.

**The SUCCESS formula** — business communication meets IBCS if it complies with the rules of seven areas:

| Letter | Area | Definition (from the standard) | Rule type |
|---|---|---|---|
| **S** | SAY — Convey a message | Every real report should convey a message, otherwise it's just a data collection. | conceptual |
| **U** | UNIFY — Apply semantic notation | Things that mean the same should look the same. | semantic |
| **C** | CONDENSE — Increase information density | All information necessary to understanding the content should, if possible, be included on one page. | perceptual |
| **C** | CHECK — Ensure visual integrity | Information should be presented in the most truthful and the most easily understood way possible. | perceptual |
| **E** | EXPRESS — Choose proper visualization | Objects should convey the message and the underlying facts as intuitively as possible. | perceptual |
| **S** | SIMPLIFY — Avoid clutter | Avoid all components which are too complicated, redundant, distracting or merely decorative. | perceptual |
| **S** | STRUCTURE — Organize content | Content should follow a logical structure; elements consistent and exhaustive without overlap. | conceptual |

UNIFY governing principle: *"Similar content should be visualized in a similar manner; what looks
the same should also mean the same. On the flip side: If the content is not the same, it should
not look the same."*

---

## Cheat sheet: IBCS semantic notation

### Scenarios (UN 3.2)

| Scenario | Code | Data type | Area fill of visualization elements | Table column header *(figure)* |
|---|---|---|---|---|
| Actual | **AC** | measured | **solid dark** (e.g. dark gray) | thick dark underline |
| Previous year / previous periods | **PY** | measured (earlier periods, in a scenario comparison) | **lighter solid** (e.g. light gray) | light gray underline |
| Plan / Budget | **PL** / **BU** | fictitious | **outlined** (bordered, framed) — areas "fill up when materializing" | double-line underline |
| Forecast | **FC** | expected | **hatched**, outlined; dark stripes in the color of measured data | hatched underline |

- Readers should recognize scenario types *"by looking at the area fill of a visualization element without having to read the labels"*. Bars, columns, line markers, scenario triangles carry the notation.
- In variance charts, the **axes** carry the notation of the reference scenario (UN 4.1).
- Stacked columns/areas, multiple lines: apply the scenario notation to the lowest segment, fill upper segments with different shades of gray; add an outline or hatch pattern if they represent planned or forecasted data.
- *"If data from multiple periods is presented in a time series there is no need for coloring earlier periods with a lighter fill."*

### Scenario comparisons (UN 4.1)

- Different time periods: *"arrange scenarios … in temporal ascending order either from left to right (horizontal axes) or from above to below (vertical axes), e.g. PY (= AC 2020), FC 2021, PL 2022."*
- Same time period (e.g. PL 2021, FC 2021, AC 2021): order *"defined by the time when the scenarios are created"*.
- Comparing measured data of different periods: use scenario labels (AC, PY) rather than period labels (2021, 2020); the period must be clear from the title, a legend or a column header.
- Visualize by **overlapped grouping** of columns/bars or with **scenario triangles** using the area coding of the reference scenario. Triangles can add a third scenario. *"AC and FC stand in the foreground of other scenarios."*

### Variances (UN 4.1)

| Impact | Color | No color available | Color vision deficiency |
|---|---|---|---|
| Positive | green | light gray | blue-green |
| Negative | red | dark gray | red |
| Neutral | blue | medium gray | blue |

- Color by **impact on business issues**, not by sign (e.g. *"cost decrease in % (green)"*). Applies to variance columns/bars, pins, difference markers, trend arrows; table numbers *"if it is helpful"*.
- These colors *"must not be confused with red and green 'traffic lights'"* (EX 2.5).
- **Absolute variances**: variance columns/bars with *"the same width and the same scale as the corresponding base value columns or bars"*.
- **Relative variances**: thin columns (vertical pins) or thin bars (horizontal pins), with **head markers**.
- Scenario to be analyzed (minuend) → **fill** of the variance column/bar or pin head (solid for AC, hatched for FC; outlined if, in special cases, the minuend is PL).
- Reference scenario (subtrahend) → **axis**: solid light for PY; outline shape (two parallel lines) for PL or BU.
- Data labels of variances: always **outside** the element, in the direction of the increase/decrease.

### Notation

| What | Notation | Example |
|---|---|---|
| Absolute variance | "Δ" prefix to the subtrahend | ΔPL = AC−PL (or FC−PL); ΔPY = AC−PY. If unclear: "AC-PL", "FC-PL" |
| Relative variance | "Δ" prefix + "%" appendix | ΔPL% = (AC−PL)/PL×100. If unclear: "(AC-PL)%" |
| Variance of percent values | percent points | AC 50% − PL 40% = +10pp |
| Relative variance of percent values | same as for absolute values | (50% − 40%) / 40% × 100 = +25% |
| Non-interpretable relative variance | "n.a." | Profit AC 30, PL −30 → ΔPL% = −200% → n.a. |
| Sign | "+" only for variances | "+13" = a variance of 13; "13" = any value |
| Year-to-date | underscore prefix | `_Jun 2021`, optionally `January_June 2021` |
| YTD average | underscore + "Ø" appended | `_Jun 2021Ø` |
| YTD last date value | underscore + full stop appended | `_Jun 2021.` |
| Year-to-go | underscore appended | `Jun 2021_` |
| Moving analyses (previous 12 months; MAT, MAA) | tilde prefix | `~Jun 2021`, `~JunØ` |
| First / last day of a period | full stop before / after | `.2021`, `.Jun` / `2021.`, `Jun.` |
| Time span | two full stops, no blanks (not an ellipsis) | `Jan..Mar` |
| Structural average | "Ø" appended or prefixed | `EuropeØ`, `Ø464` |
| Ranking | arrow appended | `country names↓`, `product sales↑` |
| Time series of different scenarios | "&" (no blanks) | `AC&PL` (8 months AC, 4 months PL) |
| Different scenarios for all periods | "and" | `AC and PY` |

### Indicators (UN 5)

| Purpose | Indicator | Color |
|---|---|---|
| Assisting purposes (differences, separating, grouping, coordinating charts) | assisting lines and assisting areas | — |
| Difference between two columns/bars | difference marker between two parallel assisting lines (optional arrowhead) | green / red / blue by impact |
| Trend | trend arrow from the first to the last period of the trend calculation, pointing in time direction (optional e.g. "CAGR: 10.8%") | green / red / blue |
| Single value referred to by the message | highlighting ellipse | blue |
| Reference standard (index, benchmark) | reference arrowhead close to the point, label ("100%", "Market avg.") next to it | black arrowhead |
| Comments | comment references, in pairs | *(figure: blue numbered circles)* |
| Different scales | scaling line / scale band | light fill *(figure: light blue)* |
| Unimportant outlier | omit the pin head, add outlier triangles pointing in the direction of growth | — |

---

## UNIFY — apply semantic notation

### UN 1 Unify terminology

**UN 1.1 Unify terms and abbreviations**
- *"Unify, compile and explain all terms and abbreviations in a clearly arranged corporate glossary including abbreviations and definitions."* A multilingual glossary may be needed.
- Short abbreviations for table **column** headers (e.g. `A/R`), long abbreviations for table **row** headers (e.g. `Acc. Receiv.`).

**UN 1.2 Unify numbers, units, and dates**
- Numbers (option: SI, ISO 80000-1): thousand delimiter = narrow blank (`1 234`); decimal sign `1,23` or `1.23`.
- Use currency and metric prefixes *"to limit the number of digits to a maximum of three in charts and four in tables"* (SI 5.2).
- Negative values: `-123` or `(123)` — the same format for all negative values within an organization.
- *"Positive values do not have a plus sign, unless they represent variances."*
- Currencies: ISO 4217 (EUR, CHF, USD, GBP). Special symbols (€, $, £) *"not recommended if a report includes many different currencies"*.
- Monetary prefixes: lower case, single digit — `kEUR`, `mEUR`, `bEUR`.
- Physical units: SI (kg, t, m, km); non-monetary prefixes `k`, `M`, `G`.
- Dates: ISO 8601 `YYYY-MM-DD`, e.g. `2021-12-31`.
- *(figure)* ❌ `23 mtr.`, `34 kg.`, `20 sec.`, `22 tons`, `[kg]`, `sqm`, `1.5.2021`, `01/05/21`, `II/2021` → ✅ `23 m`, `34 kg`, `20 s`, `22 t`, `kg`, `m²`, `2021-05-01`, `2021-Q2`, `2021-W17`, `2021-06`.

### UN 2 Unify descriptions

**UN 2.1 Unify messages**
- The message is best recognized *"if the position and the layout of the message is always the same"*.
- Position: always at the top of the page, either a) above the title or b) right of the title. b) *"is not structured as clearly as position a) but it helps saving valuable vertical space especially on pages in landscape format"*. Consistent across the organization.

**UN 2.2 Unify titles and subtitles**
- Titles identify the content *"without omitting anything that is needed to understand the content"*. *"In contrast to messages, titles do not contain any evaluating aspects, such as interpretations, conclusions, or propositions."*
- More than one object on a page: page title for the page, subtitles for objects. Title + subtitle together include reporting unit, measure and time; page-wide elements go into the page title.
- **Page title — three lines:**
  1. **Reporting unit ("who")** — legal entity, organization unit, line of business, project or combinations (`ABC Corporation, European division, Project B`). Add filter information if not exhaustive (`International Chocolate Corporation, top ten clients`). Can be split into two lines.
  2. **Business measure(s) ("what")** — *"Measures are written in bold font, their units are written in regular font"*: **Net sales** in mEUR, **margin** in %; **Headcount** in #. More than two measures → a suiting name for the set (**Income statement** in kEUR, **ROI tree** in mEUR). Redundant/minor parts → footnote (**Net sales\*** in mEUR). Optional structure dimensions and analytical annotations: `by products`, `sorted by net sales (↓)`, `indexed (2018 = 100%)`, `top ten`. Can be split into two lines.
  3. **Time, scenario, variances** — time elements are generally necessary; scenarios and variances added *"if they help to understand the page content faster"*. *"If only actual values are presented, the attribute AC can be omitted."* Time element first: `2021-Q1`, `2020-03..2021-02`, `2020 AC and PL`, `2021 AC&FC and PY`, `2018..23 AC&PL`. *"Keep it clear … too many elements tend to be confusing"* — column headers and legends are often sufficient.
- Position: very upper left corner, directly underneath the message (or at the same height, left of the message, if space is short).
- *(figure)* ❌ `Net Sales Development from January to July 2021 Alpha Corporation [mEUR]` → ✅ `Alpha Corporation` / **Net sales** in mEUR / `Jan..Jul 2021`.
- **Subtitles** identify page segments or objects; they show identifiers that **differ** between objects (`Revenue in mEUR | Sales in SKU | Avg. price in EUR/SKU`, `Apples | Pears | Oranges`); identical identifiers go into the page title. Positioned above the object, centered or left-aligned.
- **Screen pages**: responsive layout; on small landscape devices the three title lines may be written in one line separated by `|`. Hide interactive navigation objects (drop-down boxes, check boxes) *"when they are not in use or when the screen page is being printed"*.

**UN 2.3 Unify the position of legends and labels**
- **Legends** (data series labels): *"If possible, integrate legends into charts, not positioned externally. Write legends horizontally."*
  - Single column / single bar charts → integrate into the title.
  - Stacked columns → left of the leftmost or right of the rightmost column.
  - Stacked bars → centered above the top bar.
  - Grouped columns/bars → assisting lines can help assign legends.
  - Line charts → right of the line end or close to the course of the line.
  - Two value axes → externally next to symbols, or integrated next to typical points/bubbles.
- **Labels** (data labels): *"Omit labels of small visualization elements, use labels with not more than three digits, and avoid unnecessary and distracting labels."* Write horizontally; position next to the element, otherwise use connecting lines.
  - Horizontal category axes → above or below the elements; stacked columns → centered in the data points (if large enough) or outside.
  - Vertical category axes → right or left; stacked bars → centered or outside.
  - Two value axes → next to the element; large bubbles may have centered labels.
- *(figure)* ❌ external colored legend + data table under the chart → ✅ integrated legends and labels.

**UN 2.4 Unify comments** — mainly in static reports; integrate comments on an object into that object; link them to the content *"through consistently designed comment references"*.

**UN 2.5 Unify footnotes** — general explanations, abbreviations, sources, dates of retrieval and printing. *"With presentations they can be omitted from slides projected on the wall, but must be included in written material."* Position at the bottom of the page.

### UN 3 Unify dimensions

**UN 3.1 Unify measures**
- **Basic measures** (currency or physical units; not shares, not quotients): column/bar width = **2/3 of the category width** (space 1/3 for a single column); **thick lines** in line charts.
- **Ratios** (quotients of two basic measures; same unit → %; same measure → share): width = **half of basic measures, i.e. 1/3 of the category width**; **thin lines (50% of thick lines)**.
- Other measure types (value/volume, flow/stock, positive/negative impact): *"A future version of IBCS will probably address this topic."*

**UN 3.2 Unify scenarios** — see cheat sheet. Abbreviations: AC, PY, PL, BU, FC.

**UN 3.3 Unify time periods, use horizontal axes**
- *"Visualize data series over time with horizontal axes. In tables, present data series over time in columns. In both cases time moves from left to right."*
- Abbreviations: ISO 8601 `YYYY-MM-DD` is a good choice; other conventions acceptable if used consistently. Example set (UN 3.3-2): Year `2021` / `'21`; Quarter `2021-Q2` / `'21-Q2` / `Q2`; Month `2021-01`, `Jan 2021` / `'21-01`, `Jan '21` / `Jan`; Week `2021-W37` / `'21-W37` / `W37`; Day `2021-06-29`, `Jun 29, 2021` / `'21-06-29`, `Jun 29 '21` / `Jun 29`.
- Category widths: *"the longer the period the wider the category segments on the category axis"*; once allocated, the same *"at least for an entire page of a report or a screen of a dashboard"*.

**UN 3.4 Unify structure dimensions, use vertical axes**
- Structure dimensions = all dimensions that are not measures, scenarios or time (regions, organization units, products, customers, channels, accounts).
- *"In general, display structures on vertical category axes."* Exceptions: (de facto) standards such as bell curves. Custom symbols may differentiate structure dimensions.

### UN 4 Unify analyses

**UN 4.1 Unify scenario analyses** — see cheat sheet (comparisons, absolute and relative variances).

**UN 4.2 Unify time series analyses**
- YTD: accumulation (flow measures only), average (flow and stock), last date value (stock). YTG. Moving analyses (MAT, MAA) — tilde replaces the underscore.
- In charts, put the underscore/tilde as a prefix at the left side of the column end or upper side of the bar end.
- **Temporal indexing**: *"position a black arrowhead pointing right at the left of the index point. '100%' or '100' is written left of the arrowhead"*; optional horizontal assisting line.

**UN 4.3 Unify structure analyses**
- Structural average: "Ø" + optional assisting line.
- Ranking: arrow appended, if helpful.
- Selecting (top ten, last quartile…): *"A future version of IBCS may address the visualization."*
- Structural indexing: black arrowhead close to the index point, "100%"/"100" next to it; optional assisting line.
- Structural normalizing (shares of a whole): assisting line representing 100%, black arrowhead at one end, "100%"/"100" next to it.

**UN 4.4 Unify adjustment analyses** — currency, inflation, seasonal effects (e.g. AC re-measured at PY exchange rates). No visualization concept yet.

### UN 5 Unify indicators

**UN 5.1 Unify highlighting indicators** — see cheat sheet. Plus: *"Add visualization elements for not-valid values, limits, or other relevant phenomena. Standardize and document these 'signals'."*

**UN 5.2 Unify scaling indicators** — scaling line: *"parallel to the category axis at the same numerical height in all charts"* (a differing scale, usually by a multiplier of ten, becomes obvious). Scale band: fill the area between scaling line and category axis with light color.

**UN 5.3 Unify outlier indicators** — for outliers not important for business (e.g. a big relative variance of a small value): *"do not scale the whole chart to this outlier"*; omit the pin head and add outlier triangles pointing in the direction of growth.

---

## SAY — convey a message

**SA 1 Know objectives**
- SA 1.1 Know own goals — *"The least goal is to inform about an interesting detection. A higher goal is to make the reader understand a problem by explaining it. The ultimate goal is to get a decision on a suggestion provided and to cause corresponding actions."*
- SA 1.2 Know target audience — function, position, knowledge, attitude, expectations; *"Who might object to the message and why?"*

**SA 2 Introduce message**
- SA 2.1 Map situation — present related facts and goals already known; *"begin with a positive or generally accepted description of the situation"*.
- SA 2.2 Explain problem — the challenge or complication.
- SA 2.3 Raise question — from the recipient's perspective; the message is the answer.

**SA 3 Deliver message**
- SA 3.1 Detect, explain, or suggest — *"deliver these messages in a complete sentence"*; detections *"should be formulated as precisely as possible"*. Example (figure): ❌ `"Sales down"` → ✅ `"Sales are mEUR 5 below…" … "because of a 10% decrease…" … "therefore we should change…"`.
- SA 3.2 Say message first — *"This message usually comes first and is proven afterwards."* Be cautious in presentations with bad, unexpected or unpleasant messages, or where directness is considered impolite.

**SA 4 Support message**
- SA 4.1 Provide evidence — facts and figures; *"a presentation slide should itself explain or prove the speaker's message"*.
- SA 4.2 Use precise words — avoid "relevant", "significant" (in common speech). *(figure)* ❌ `Relevant cost cut`, `Around 100 units`, `Much better than plan` → ✅ `Cost cut of 3.5 mEUR`, `Between 98 and 102 units`, `3% above plan`.
- SA 4.3 Highlight message — *"Objects and pages without highlighting indicators tend to be a statistic rather than a report."*
- SA 4.4 Name sources — projected slides can omit them; written reports and handouts must include them.
- SA 4.5 Link comments — number comments related to specific parts of a page and link them; post them in text boxes on free areas.

**SA 5 Summarize message**
- SA 5.1 Repeat message — avoid "Thank you for your attention"; sum up the message one last time. Not necessary in reports.
- SA 5.2 Explain consequences — conclude with proposals for decisions and their consequences.

---

## STRUCTURE — organize content

**ST 1 Use consistent elements** — ST 1.1 items of the same type; ST 1.2 statements of the same type (e.g. all suggestions); ST 1.3 grammatically consistent wording (e.g. imperative verb + noun); ST 1.4 visualizations uniform in layout, colors, forms, fonts.

**ST 2 Build non-overlapping elements** (mutually exclusive) — ST 2.1 report structures (chapters must not cover the same aspects); ST 2.2 business measures on one hierarchical level (❌ material costs + costs of goods sold; depreciation + fixed costs); ST 2.3 structure dimensions (❌ Scandinavia + Norway, Sweden…).

**ST 3 Build collectively exhaustive elements** — ST 3.1 exhaustive arguments; ST 3.2 structures in charts and tables add up to 100%, often via a remainder element ("rest of…"). ME + CE = **MECE**.

**ST 4 Build hierarchical structures**
- ST 4.1 Deductive reasoning (logical flow): statement → comment → conclusion → message; answers "why". *"Best applied in controversial discussions"*, but *"the whole argumentation can collapse if any statements are questionable"*.
- ST 4.2 Inductive reasoning (logical group): *"homogenous, non-overlapping, and collectively exhaustive arguments culminating in a message"* — *"a powerful argumentation"*.

**ST 5 Visualize structure** — ST 5.1 in reports (outlines, dashboards, summaries, binder tabs); ST 5.2 in tables (structure recognizable in columns and rows, e.g. cities → regions → country); ST 5.3 in notes.

---

## EXPRESS — choose proper visualization

### EX 1 Use appropriate object types

*"We use tables when looking up data."* Tables are clear and honest and do not compete with charts. Charts *"are always biased"*; *"charts in reports conveying messages cannot be replaced by tables."*

**EX 1.1 Use appropriate chart types**

Chart selection matrix (figure EX 1.1-1):

| Analysis | Time series — data points (columns) | Time series — patterns (lines and areas) | Structure — structural comparisons (bars) |
|---|---|---|---|
| Basic | columns | line | bars |
| Accumulation (stacked) | stacked columns | stacked areas | stacked bars |
| Part to whole (normalized) | 100% stacked columns | 100% areas | 100% stacked bars |
| Reference (indexed) | columns + index | line + index | bars + index |
| Contribution (basic waterfall) | column waterfall | — | bar waterfall |
| Data series comparison (grouped) | grouped columns | multiple lines | grouped bars |
| Absolute variance (green good / red bad) | variance columns | variance areas | variance bars |
| Relative variance (green / red pins) | pins | — | pins |
| Contribution to variance (waterfall, green/red) | variance column waterfall | — | variance bar waterfall |

**Charts with horizontal category axes (time series):**
- No vertical value axis needed — the elements carry their own values.
- *Single column*: legend in the chart title; positive values labeled above, negative below; columns in the foreground of the axis.
- *Stacked column*: legends far left (right-aligned) or far right (left-aligned), vertically centered on segments; segment labels inside, sum label above (below if negative). Only if all values are positive or all negative; *"More than 5 data series will only work well in the case of little variations."* Put the series of central importance directly on the axis.
- *Grouped column*: reference scenario placed behind the primary one; a third scenario via a reference scenario triangle; alternatively a single column + reference scenario triangles.
- *Horizontal pin chart*: relative variances over time; pin head fill = primary scenario.
- *Horizontal waterfalls*: base columns, contribution columns, totals columns, connected by assisting lines. **Growth waterfall** — stock measure at points in time, contributions = changes (no vertical equivalent). **Horizontal variance waterfall** — flow measure, contributions = periodical variances.
- *Line chart*: for data series with many data points (better data-ink ratio). *"Lines should not be used for the presentation of data series with only a few values"* (they imply a continuous timeline). Cannot be stacked → area charts. More than three intersecting lines → small multiples. Legend right of the far-right point or left of the far-left point; label peaks above, valleys below; don't label every point.
- Boxplot and area charts: no specific notation yet.

**Charts with vertical category axes (structure):**
- Sequence of elements depends on the analysis (see structure analyses). No horizontal value axis needed.
- *"Do not use lines in vertical charts as they could be interpreted as trends or developments."*
- *Single bar*: legend in the title; positive labels right, negative left; same category width for corresponding analyses.
- *Stacked bar*: legends above the top or below the bottom bar, centered on segments; same sign and ≤ 5 series rule as stacked columns.
- *Grouped bar*: reference scenario behind; triangles as an alternative.
- *Vertical pin chart*: relative variances in a structure analysis.
- *Vertical waterfalls*: **calculation waterfall** (base/result measures, e.g. sales → EBIT, with intermediate subtotals; no horizontal equivalent) and **vertical variance waterfall** (variances in structure between periods/scenarios).
- *Remainder bar*: many elements → sort descending, accumulate the smallest in a "rest of…" bar, separated by a wider gap; exclude it from averaging, ranking and selecting.

**Charts with two value axes:** scattergrams; bubble charts (bubble area = third dimension; pie segments in bubbles = fourth). No specific notation yet — derive from column, bar and line charts.

**EX 1.2 Use appropriate table types**

Column layout principles (all column types):
- **Width**: identical within a column type, *"should not depend on the text length of the respective column header"*.
- **Orientation**: right-align numerical columns, left-align non-numerical; column headers aligned like the column.
- **Vertical lines and gaps**: very light or omitted; use white lines or gaps — narrow gap (B1) between columns of the same type, wider gap (B2) between groups.

Column types:
- *Row header column* — usually leftmost, wider; short texts (abbreviations, footnotes); wider gap to the number columns.
- *Scenario columns* — same width; sequence per UN 4.1.
- *Variance columns* — absolute or relative variances.
- *Time columns* — temporal order left to right.
- *Measure columns* — glossary abbreviations; wider gap after intermediate results.
- *Structure columns* — elements of a structure dimension.
- *"Of which" columns* — smaller font, not separated from the mother column, positioned right of it.
- *Remainder column* — e.g. "Other cost".
- *"Percent of" columns* — smaller font.
- *Totals columns* — right of their group; bold, or light gray background if helpful.
- *Hierarchical columns* — parent right of its children; separated by wider gaps.
- *Nested columns* — one type repeats within the other; groups separated by wider gaps.

Row layout principles: identical height within a row type; light horizontal lines increase legibility. *"Time periods and points of time, scenarios, and variances should be displayed in columns rather than in rows."*

Row types:
- *Column header row* — top; two or more rows to group columns; abbreviate or use footnotes.
- *Measure rows* — results rows separated by solid lines, consistent distinct design (bold, light gray background if helpful), additional gap below.
- *Structure rows*.
- *"Of which" rows* — aggregated row **above** them; e.g. smaller height, smaller font, no separating horizontal line, right-aligned row header.
- *Remainder row* — e.g. "Rest of world"; exclude from averaging, ranking, selecting.
- *"Percent of" rows* — smaller font.
- *Totals rows* — **below** their group, separated by solid lines; bold, light gray background if helpful.
- *Hierarchical rows* — parent rows below child rows; parents separated by wider gaps. Siblings should be homogeneous and MECE.
- *Nested rows* — groups separated by wider gaps.

Table types: **time series tables** (time columns × measure/structure rows), **variance tables** (scenario + variance columns × measure/structure rows), **cross tables** (structure × structure), **combined tables** (more than one column and/or row type, side by side or nested).

### EX 2 Replace inappropriate chart types
- EX 2.1 Replace pie and ring charts — better: bar charts or stacked columns. Exception: pies positioned at a point on a map.
- EX 2.2 Replace gauges, speedometers — bar charts for structures, column charts for development over time.
- EX 2.3 Replace radar and funnel charts — radar only for two-dimensional analyses or when the circular arrangement has meaning (compass directions). Funnels and other artificial forms mislead when area/length/volume don't correspond to the values.
- EX 2.4 Replace spaghetti charts — more than three or four intersecting lines → small multiples; unavoidable when exact heights of several lines must be compared.
- EX 2.5 Replace traffic lights — only for "yes or no" situations; otherwise e.g. bar charts.

### EX 3 Replace inappropriate representations
- EX 3.1 Prefer quantitative representations — no more than three or four conceptual representations in a one-hour presentation.
- EX 3.2 Avoid text slides in presentations — texts recited or in the handout; bullet lists only in the handout (exceptions: definitions, quotes).

### EX 4 Add comparisons
- EX 4.1 Add scenarios (PL, PY) whenever available. EX 4.2 Add variances.

### EX 5 Explain causes
- EX 5.1 Show tree structures; EX 5.2 Show clusters; EX 5.3 Show correlations.

---

## SIMPLIFY — avoid clutter

**SI 1 Avoid unnecessary components**
- SI 1.1 Avoid cluttered layouts — pictures, backgrounds, logos and corporate-design elements without meaning.
- SI 1.2 Avoid colored or filled backgrounds — *"Numbers and labels are easiest to read when depicted in black on a white background."*
- SI 1.3 Avoid animation and transition effects — only "appear" for gradual development of a slide.

**SI 2 Avoid decorative styles**
- SI 2.1 Avoid frames, shades, and pseudo-3D.
- SI 2.2 Avoid decorative colors — *"use colors only if they convey meaning"*.
- SI 2.3 Avoid decorative fonts — *"Save bold and cursive fonts for making distinctions."*

**SI 3 Replace with cleaner layout**
- SI 3.1 Replace grid lines and value axes with data labels — gridlines can be useful with many series/points or in small charts (small multiples).
- SI 3.2 Avoid vertical lines by right-aligning data and column headers.

**SI 4 Avoid redundancies** (some redundancy can help, e.g. period in title and chart)
- SI 4.1 Avoid superfluous extra words — "sum", "total" (*"No difference exists between 'Europe' and 'Sum of Europe'"*).
- SI 4.2 Avoid obvious terms — "chart analysis", "development", "comment", "table", "statistics", "report", "visualization", "structure", "trend".
- SI 4.3 Avoid repeated words — "division" in "division A, division B"; "2020" in "Q1 2020, Q2 2020".

**SI 5 Avoid distracting details**
- SI 5.1 Avoid labels for small values — unless special reference is made to them (then assisting lines may be needed).
- SI 5.2 Avoid long numbers — more than three digits in charts and four in tables.
- SI 5.3 Avoid unnecessary labels — omit labels of points that are not extreme or of special importance.

---

## CONDENSE — increase information density

**CO 1 Use small components** — CO 1.1 small fonts (avoid oversize fonts); CO 1.2 small elements; CO 1.3 small objects — *"as small as possible – yet only so small so that the objects and all its details and labels can be read easily"*.

**CO 2 Maximize use of space** — CO 2.1 narrow page margins; CO 2.2 reduce empty space (page layout and objects).

**CO 3 Add data** — CO 3.1 add data points (e.g. 36 months instead of 12); CO 3.2 add dimensions.

**CO 4 Add elements** (combined charts are treated as one entity)
- CO 4.1 Overlay charts — same category axis; different value axes (columns + line) or the same value axis (e.g. integrated variances). Integrated variances save space but are hard to label; *"If there is enough space, use multi-tier charts instead."*
- CO 4.2 Multi-tier charts — additional tiers on the same category axis, mostly variances along with base values; secondary chart above (horizontal charts) or right (vertical charts); value axes of the same unit scaled identically.
- CO 4.3 Extended charts — additional charts on a virtual extension of the category axis (e.g. monthly average), same value axis.
- CO 4.4 Embed chart elements in tables — table bars (categories = table rows, incl. pins and waterfalls); sparklines only if scaled properly (e.g. indexed); traffic lights only for two or three states.
- CO 4.5 Embed explanations — in written reports and handouts.

**CO 5 Add objects**
- CO 5.1 Show small multiples — same chart type and same scale; up to around 25 charts per page, otherwise an "Others" chart; bigger values → increase that chart's size, not its scale.
- CO 5.2 Show related charts on one page (multi-charts, ratio trees) — charts must have a useful relationship; indicate different scales with scaling indicators. Ratio trees: broken down mostly from left to right, preferably identical size.
- CO 5.3 Show chart-table combinations — useful if both show supplementary data; *"Tables simply listing the numbers of a chart are superfluous in most cases."*
- CO 5.4 Show charts and tables in text pages — close to the phrase carrying the message; text pages and embedded objects have a title and, if possible, a message.

---

## CHECK — ensure visual integrity

**CH 1 Avoid manipulated axes**
- CH 1.1 Avoid truncated axes — *"value axes should generally start at zero"*. Exception: indexed data with small variances from 100% — then position category labels at the 100% line.
- CH 1.2 Avoid logarithmic axes.
- CH 1.3 Avoid different class sizes — identical class widths in histograms.

**CH 2 Avoid manipulated visualization elements**
- CH 2.1 Avoid clipped visualization elements (broken columns).
- CH 2.2 Use creative solutions for challenging scaling issues (e.g. two- or three-dimensional elements for values differing by orders of magnitude).

**CH 3 Avoid misleading representations**
- CH 3.1 Use correct area comparisons, prefer linear ones — area must correspond to the value, not diameter or height.
- CH 3.2 Use correct volume comparisons, prefer linear ones.
- CH 3.3 Avoid misleading colored areas in maps — colored areas only for area-related figures (precipitation per m², population density); otherwise columns/bars of identical scale (or pies) on the map.

**CH 4 Use the same scales**
- CH 4.1 Use identical scale for the same unit — use a consistent scaling concept for the whole report if possible.
- CH 4.2 Size charts to given data.
- CH 4.3 Use scaling indicators if necessary.
- CH 4.4 Use outlier indicators if necessary.
- CH 4.5 Use magnifying glasses — mark the zoomed part and link it to a second chart on a bigger scale.

**CH 5 Show data adjustments** — CH 5.1 show the impact of inflation; CH 5.2 show the currency impact.
