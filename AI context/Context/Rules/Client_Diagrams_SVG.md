# Client explanation diagrams as SVG (since 2026-11-01)

When a client letter needs a picture (where the sales go, old vs new logic, a flow, a before / after), draw it as a
hand-written **SVG**, not a screenshot or a PNG chart. First use: ClientC, Dror's October sales in the current report vs
Sales NEW — `Agency\ClientC\Sales Rep\DrorSales_Allocation_2026-11-01.svg`.

## Why SVG

- **Vectors, rebuildable:** plain text, so the next version is a few string edits (new amounts, names, dates), not a redraw.
- **Editable by the user:** PowerPoint → Insert → Pictures → the `.svg` → Graphics Format → **Convert to Shape** — every
  box, band and text becomes a normal shape. Outlook / Word insert it as a picture too.
- **Cheap:** no Desktop, no data refresh, no image tokens except one verification render.

## Recipe

1. **Numbers first:** take them from the checked source (letter, DAX query, context file), never estimate. Name the
   source and the data date in the footer.
2. **Pick the form** (standard shapes only):
   - money / quantity moving from A to B, split or lost → **flow (Sankey-style) bands**, band width proportional to amount
     (state the scale in a comment, e.g. `160 px = 11,125 ₪`; minimum ~8 px so small bands stay visible);
   - old vs new logic → **two stacked panels**, same source box on the left, same layout, so only the right side differs;
   - hierarchy / team → boxes + bracket; process → boxes + arrows.
3. **Write the SVG by hand** (Write tool): `viewBox` 1000 wide, white background `rect`, font `Segoe UI, Arial`, one
   `<text>` per line (`text-anchor="middle"` inside boxes), bands = closed cubic paths
   `M x1,y1 C mid,y1 mid,y2 x2,y2 L x2,y3 C mid,y3 mid,y4 x1,y4 Z`. "Lost / not counted" = hatched `pattern` + dashed box
   + red label. Title (what + period), subtitle (rule / filter), panel captions explain the logic in one line.
4. **Render and look once:** headless Edge → PNG in the scratchpad, then Read the PNG:
   ```powershell
   & "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu `
     --window-size=1000,700 --screenshot="<scratchpad>\x.png" ([uri]"<file.svg>").AbsoluteUri
   ```
5. Save next to the letter (`<Client>\...\<Topic>_<yyyy-MM-dd>.svg`) and link it.

## Hebrew gotchas (bidi in SVG)

- **No brackets next to Hebrew:** `Yossi (יוסי)` renders with mirrored brackets; LRM marks (`&#x200E;`) do not fix it in
  Chrome / Edge. Use `English / עברית` instead.
- **Hebrew at the end of the line:** `Oded / עודד · 540 ₪` scrambles; write `540 ₪ · Oded / עודד`.
- **No digits glued to Hebrew:** `08-דרור בנימיני` renders as `דרור בנימיני-08`; put the Hebrew name alone on its own
  line (`direction="rtl"`) and the code on the English line.
- Hebrew is always paired with English (rule "Hebrew always translated").

## He / En pair for the client

Every client diagram is a pair: `<name>.svg` (English, `English / עברית` labels) + `<name>_HE.svg` (Hebrew only, mirrored).
Hebrew version rules:
- **Mirror the layout:** source on the right, flow / bars to the left, labels in the right column, totals on the left
  (new x = 1000 − x − width). Timelines run right to left.
- Right-aligned text = `direction="rtl" text-anchor="start"` at the right edge; centred text = `text-anchor="middle"`.
- Inside an RTL line, brackets and numbers are fine, but **a date range** `01–26.10.2026` flips → write `מ-01.10 עד 26.10.2026`;
  a line that starts with a number followed by Latin (`2. Sales NEW`) flips → put Hebrew first (`2. דוח הבדיקה – Sales NEW`).
- Render the Hebrew file too; check every line that mixes digits / Latin with Hebrew.
- Write the file as UTF-8 without BOM (PowerShell: `New-Object Text.UTF8Encoding $false`).
