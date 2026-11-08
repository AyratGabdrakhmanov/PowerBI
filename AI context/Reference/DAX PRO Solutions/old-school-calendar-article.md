# The Old-School Calendar: No FORMAT(), Just Dates — Even for ISO Weeks

In this article I walk through an old-school, genuinely date-based Calendar technique that can render an ISO week such as `W01: 29.12 - 04.01` from a single date — with no `FORMAT()` involved.

What's described here is only a lightly polished version of Yury's original idea. I owe most of what I know about DAX modelling to him — thank you, Yury.

## The idea

The idea is simple: lean on the **Date** type, avoid string output from `FORMAT()`, and add just a pinch of **boolean / integer** columns.

Doing so buys you several benefits:

1. **No extra sort columns.** Dates are stored internally as numbers, so they sort chronologically on their own.
2. **No `REMOVEFILTER()` housekeeping.** Because there are no separate sort columns, you never have to `REMOVEFILTER()` them inside `CALCULATE()`.
3. **Free translation.** Without `FORMAT()` and a hard-coded culture, the labels translate automatically according to `USERCULTURE()`.
4. **Shorter `CALCULATE()`.** A boolean column *is* the filter — no comparison or condition needed:

   ```dax
   CALCULATE (
       [Sales],
       'Calendar'[Closed Period]   // boolean (or integer 1/0)
   )
   ```

5. **Integer 0/1 as an option.** Instead of a pure boolean I sometimes use an integer with `0`/`1` values, since a format string can turn them into `"Yes"`/`"No"` later.
6. **Enough containers even for weeks.** A datetime value carries several slots (year, month, day, hour, minute, second) — enough to encode an ISO week range like `W01: 29.12 - 04.01`.
7. **Chart-friendly.** It works well with continuous / categorical axes, where a Date type is expected.
8. **Reusable as a key.** In other tables — like Field Parameters (*link to the FP article*) — the same date can serve as the relationship key back to Calendar.

Let's look at some practical implementation examples. All columns below are added over the base date list, with these helpers in scope:

```dax
VAR __TodayDate   = TODAY ()
VAR __TodayMonday = __TodayDate - WEEKDAY ( __TodayDate, 2 ) + 1
```

## Year

```dax
, "Year",         YEAR ( [Date] )
, "Year Date",    EOMONTH ( [Date], - MONTH ( [Date] ) ) + 1    // yyyy
, "Year ID",      DATEDIFF ( __TodayDate, [Date], YEAR )
, "Current Year", YEAR ( [Date] ) = YEAR ( __TodayDate )
```

**Year** — a plain integer, nothing to add.

**Year Date** stores the first date of the corresponding year (1 January); the format `"yyyy"` shows just the year. Step by step for `[Date] = 20 Oct 2026`:

- `EOMONTH ( [Date], - MONTH ( [Date] ) )` — stepping back `M` months from month `M` lands in month `0`, i.e. December of the previous year → `31 Dec 2025`.
- `+ 1` → `1 Jan 2026`.
- formatted as `"yyyy"` → `2026`.

**Year ID** — the ID pattern, reusable for years, months and any other grain. `DATEDIFF ( start, end, YEAR )` counts **crossed year boundaries** (January-1 crossings), not 365-day spans. So `0` = current period, negative = history, positive = future — a handy way to count periods relative to today.

**Current Year** — the "current period" pattern: a simple `TRUE`/`FALSE` compared against today. Also reusable across grains.

## Half-year

```dax
, "Half Of Year", DATE ( YEAR ( [Date] ), ROUNDDOWN ( ( MONTH ( [Date] ) - 1 ) / 6, 0 ) + 1, 1 )   // \Hm - yyyy
```

**Half Of Year** stores the first date of the half-year: `1 Jan` for H1 and `1 Jul` for H2. The format `"\Hm - yyyy"` shows `H1 - 2026` / `H2 - 2026`.

By argument of `DATE ( year, month, day )`:

- `year` = `YEAR([Date])` — the same year.
- `day` = `1` — always the first.
- `month` = `ROUNDDOWN ( ( MONTH([Date]) - 1 ) / 6, 0 ) + 1` — the whole trick, collapsing the month into `1` or `7`.

| `MONTH([Date])` | `(M − 1) / 6` | `ROUNDDOWN` | `+ 1` → month |
|---|---|---|---|
| 1–6 (Jan–Jun) | 0 … 0.83 | 0 | **1** (January) |
| 7–12 (Jul–Dec) | 1 … 1.83 | 1 | **7** (July) |

The `- 1` in `(MONTH - 1)` shifts the numbering to zero so that dividing by 6 yields exactly two buckets (`0` and `1`). Without it, January would give `1/6 → 0`, but December would give `12/6 = 2` — a nonexistent third segment.

## Quarter

```dax
, "Quarter Year",    DATE ( YEAR ( [Date] ), ( QUARTER ( [Date] ) - 1 ) * 3 + 1, QUARTER ( [Date] ) )   // yyyy \Qd
, "Quarter Name",    DATE ( YEAR ( [Date] ), ( QUARTER ( [Date] ) - 1 ) * 3 + 1, QUARTER ( [Date] ) )   // \Qd
, "Quarter ID",      DATEDIFF ( __TodayDate, [Date], QUARTER )   // 0 = current quarter
, "Current Quarter", QUARTER ( [Date] ) = QUARTER ( __TodayDate ) && YEAR ( [Date] ) = YEAR ( __TodayDate )
```

**Quarter Year / Quarter Name** — same date, different format: `2026 Q3` or simply `Q3`, still sortable.

Both store a date **inside the target quarter**, where the month is the first month of the quarter and the day is the quarter number. That day is what later prints as `Q1`…`Q4`. By argument of `DATE ( year, month, day )`:

- `year` = `YEAR([Date])` — the same year.
- `month` = `( QUARTER([Date]) - 1 ) * 3 + 1` — the first month of the quarter (`1/4/7/10`).
- `day` = `QUARTER([Date])` — the quarter number (1–4), placed in the day slot.

Two independent mechanisms live in one date:

- the **month** (`1/4/7/10`) gives the correct chronological position — Q1 before Q2, and so on; sorting is honest.
- the **day** (1–4) is pure display payload: the format code `d` reads it back out as the quarter number.

One caveat: if you want a single chart with the quarter number on the X axis and one line per year, this won't work — you'll need a plain `QUARTER ( [Date] )` column instead.

## Month

```dax
, "Month Year",    EOMONTH ( [Date], -1 ) + 1                          // mmm yyyy
, "Month Name",    EOMONTH ( [Date], -1 ) + 1                          // mmm
, "Month ID",      DATEDIFF ( __TodayDate, [Date], MONTH )             // 0 = current month
, "Current Month", EOMONTH ( [Date], 0 ) = EOMONTH ( __TodayDate, 0 )  // OR  Month ID = 0
```

Same approaches, nothing new: the first date of the month, a relative ID, and a current-period flag.

## Working days

```dax
, "Working Day Of Year",
        VAR __CurrentYear = YEAR ( [Date] )
        RETURN
            RANKX (
                FILTER (
                    __Dates,
                    YEAR ( [Date] ) = __CurrentYear
                        && NOT WEEKDAY ( [Date], 2 ) IN { 6, 7 }
                ),
                [Date], [Date], ASC, DENSE
            )
```

**Working Day Of Year** returns the ordinal number of a working day within its year: the 1st working day = 1, the 2nd = 2, and so on, skipping weekends (here `{ 6, 7 }` = Saturday/Sunday).

It's also useful for comparing the working days of a selected period against the matching working days a year earlier.

## Period flags

```dax
, "Closed Period", [Date] <= __TodayDate
, "Today",         [Date] =  __TodayDate
```

Boolean columns. Remember to keep the DAX short by using them directly as a filter argument, e.g. `'Calendar'[Closed Period]`.

## ISO weeks

```dax
, "ISO Year",      YEAR ( [Date] - WEEKDAY ( [Date], 2 ) + 4 )
, "ISO Week",      WEEKNUM ( [Date], 21 )
, "ISO Week Date", [Date] + TIME ( 0, 0, WEEKNUM ( [Date], 21 ) )   // \Ws dd mmm yy
, "ISO Week ID",   DATEDIFF ( __TodayMonday, [Date] - WEEKDAY ( [Date], 2 ) + 1, DAY ) / 7   // 0 = current week
```

**ISO Year** — an integer following ISO 8601: a week belongs to the year of its **Thursday**. Shift the date to that week's Thursday (`- WEEKDAY + 4`) and take its year.

**ISO Week** — the standard `WEEKNUM ( [Date], 21 )` for ISO numbering.

**ISO Week ID** — the number of weeks between this week's Monday and today's Monday: `0` = current week, negative = history, positive = future.

**ISO Week Date** is one row per day, with the ISO week number mixed into the **seconds** slot. The format `"\Ws dd mmm yy"` shows `W` + week number + the date itself.

- `[Date]` — the real date (its date part, time `00:00:00`).
- `TIME ( 0, 0, WEEKNUM ( [Date], 21 ) )` — a time of `00:00:SS`, where the seconds equal the ISO week number (1–53).
- the sum → the same date, now with seconds equal to the week number.

The format reads it back:

| Code | Source | Example (25 Feb 2026, week 9) |
|---|---|---|
| `\W` | literal | `W` |
| `s` | seconds = week number | `9` |
| `dd` | day of the date | `25` |
| `mmm` | month of the date | `Feb` |
| `yy` | year of the date (2 digits) | `26` |

Result: `W9 25 Feb 26`.

The seconds (1–53) are a fraction of a single day, so they can't push the value onto another date — the column sorts exactly like a plain date. Note that `s` prints without a leading zero (`9`, not `09`); use `ss` if you want two digits.

## The nail in the program: ISO Week as Date

```dax
, "ISO Week as Date",
        VAR __Weekday   = WEEKDAY ( [Date], 2 )
        VAR __WeekStart = [Date] - __Weekday + 1
        VAR __WeekEnd   = [Date] - __Weekday + 7
        RETURN
            __WeekStart + TIME ( MONTH ( __WeekEnd ), WEEKNUM ( [Date], 21 ), DAY ( __WeekEnd ) )
        // format "\Wnn: dd.mm - ss.hh"  →  "W09: 29.02 - 06.03"
```

This is the masterpiece. One datetime packs **two independent things**: the real Monday date (for sorting and relationships) and three display numbers hidden in the time part.

**Week boundaries (plain calendar, Mon–Sun)**

- `__Weekday = WEEKDAY ( [Date], 2 )` — the weekday, Mon = 1 … Sun = 7.
- `__WeekStart = [Date] - __Weekday + 1` — the **Monday** of the week.
- `__WeekEnd = [Date] - __Weekday + 7` — the **Sunday** of the week.

For any date within the week, `__WeekStart` / `__WeekEnd` are the same, so all 7 days collapse into one week label.

**What goes into the value**

```dax
__WeekStart + TIME ( MONTH ( __WeekEnd ), WEEKNUM ( [Date], 21 ), DAY ( __WeekEnd ) )
```

| datetime slot | Value | Source | Range | Fits? |
|---|---|---|---|---|
| **date** | `__WeekStart` (Monday) | calendar | real date | — |
| **hours** | `MONTH ( __WeekEnd )` — month of Sunday | calendar | 1–12 | in 0–23 ✔ |
| **minutes** | `WEEKNUM ( [Date], 21 )` — week number | **ISO** | 1–53 | in 0–59 ✔ |
| **seconds** | `DAY ( __WeekEnd )` — day of Sunday | calendar | 1–31 | in 0–59 ✔ |

Nothing overflows — each number fits its slot, so `TIME()` never spills into a neighbouring one.

**How the format reads it back**

Format `"\Wnn: dd.mm - ss.hh"`:

| Code | Reads from | Meaning | Example |
|---|---|---|---|
| `\W` | literal | the letter W | `W` |
| `nn` | minutes | week number (ISO) | `09` |
| `dd.mm` | date | day.month of the **Monday** | `29.02` |
| `ss.hh` | seconds.hours | day.month of the **Sunday** | `06.03` |

Result: `W09: 29.02 - 06.03` — "ISO week 09, calendar Mon 29.02 – Sun 06.03".

**Two systems on purpose**

Two dimensions are deliberately kept apart here:

- the **week number** follows **ISO** (`nn`, from the minutes), so numbering matches the international standard;
- the **date range** follows the plain **calendar** week Mon–Sun (boundaries from `WEEKDAY`), so a reader sees the familiar Monday-to-Sunday span.

The label honestly says: here is the ISO week number, and here are its calendar edge dates.

**Why sorting stays honest**

Power BI orders by the full datetime. The high-order part is the Monday date, which is unique per week. The time part (month / week / day of the week-end) is a fraction of a day and physically cannot move the value onto another date. So weeks stay strictly chronological, and the time part is display payload only.

**Nice touches**

- **Month boundaries print themselves.** `dd.mm` takes the Monday's month and `ss.hh` the Sunday's, so a week that straddles a boundary shows both (`29.02 - 06.03`). That's exactly why the week-end's month is hidden in the hours.
- **`nn` from the minutes gives a leading zero** (`09`), unlike `s` in *ISO Week Date*.

## One more thing

That's the whole approach: honest dates underneath, custom labels on top — all the way down to ISO weeks. Grab the file and poke at the week columns; that's where it gets fun.
