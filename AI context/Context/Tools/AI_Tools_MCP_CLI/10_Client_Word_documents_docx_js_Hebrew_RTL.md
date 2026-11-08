Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## Client Word documents (docx-js, Hebrew RTL)

- Examples: `_Documentation\Scripts\ClientDocs\ClientDoc_HE_example.js` / `ClientDoc_EN_example.js` (title, summary
  table, sections, bullets, numbered list, number table). Run `node <script> <out.docx>`; `docx` is not global —
  `npm install docx` in the script folder first.
- Hebrew RTL gotchas: paragraphs `bidirectional: true` + `AlignmentType.RIGHT`; table `visuallyRightToLeft: true`;
  list level `alignment: LEFT` + `indent.left` (RIGHT puts bullets on the left); `rightToLeft` only on runs with
  Hebrew letters (Latin-only RTL runs flip "606208 CEO"); number cells as LTR paragraphs (else `-4,568` → `4,568-`).
- No LibreOffice / pdftoppm here: render via Word COM (`Documents.Open` → `ExportAsFixedFormat(pdf, 17)`) and
  PyMuPDF (`pip install pymupdf`) to PNG, then look at the pages.
- A docx open in Word is locked (EBUSY) — build to the scratchpad, copy once it is closed.
