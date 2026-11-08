const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType,
  ShadingType, AlignmentType, HeadingLevel, LevelFormat, BorderStyle,
} = require('docx');

const OUT = process.argv[2];
const FONT = 'Arial';

// text with **bold** segments
function runs(text, extra = {}) {
  return text.split(/(\*\*[^*]+\*\*)/).filter(Boolean).map(s =>
    new TextRun({ text: s.replace(/\*\*/g, ''), bold: s.startsWith('**') || extra.bold, font: FONT, ...extra }));
}
const p = (t, o = {}) => new Paragraph({ spacing: { after: 120 }, children: runs(t), ...o });
const h = t => new Paragraph({ heading: HeadingLevel.HEADING_1, children: runs(t) });
const bullet = t => p(t, { numbering: { reference: 'b', level: 0 } });
const num = t => p(t, { numbering: { reference: 'n', level: 0 } });

function table(widths, rows, opts = {}) {
  const total = widths.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: total, type: WidthType.DXA }, columnWidths: widths,
    rows: rows.map((r, i) => new TableRow({ tableHeader: i === 0, children: r.map((c, j) => {
      const head = i === 0, totalRow = opts.totalLast && i === rows.length - 1;
      const hl = opts.highlight && opts.highlight === i;
      return new TableCell({
        width: { size: widths[j], type: WidthType.DXA },
        shading: head ? { type: ShadingType.CLEAR, fill: '1F4E79', color: 'auto' }
          : hl ? { type: ShadingType.CLEAR, fill: 'FFF2CC', color: 'auto' }
          : totalRow ? { type: ShadingType.CLEAR, fill: 'DEEAF6', color: 'auto' } : undefined,
        margins: { top: 60, bottom: 60, left: 100, right: 100 },
        children: [new Paragraph({ keepNext: i < rows.length - 1,
          alignment: opts.numCols && opts.numCols.includes(j) ? AlignmentType.RIGHT : AlignmentType.LEFT,
          children: runs(c, { bold: head || totalRow, color: head ? 'FFFFFF' : undefined }) })],
      });
    }) })),
  });
}

const doc = new Document({
  styles: {
    default: { document: { run: { font: FONT, size: 22 } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 30, bold: true, color: '1F4E79' },
        paragraph: { spacing: { before: 300, after: 140 }, outlineLevel: 0 } },
      { id: 'Title', name: 'Title', basedOn: 'Normal', next: 'Normal',
        run: { font: FONT, size: 40, bold: true, color: '1F4E79' }, paragraph: { spacing: { after: 80 } } },
    ],
  },
  numbering: { config: [
    { reference: 'b', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT,
      style: { paragraph: { indent: { left: 500, hanging: 300 } } } }] },
    { reference: 'n', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
      style: { paragraph: { indent: { left: 500, hanging: 300 } } } }] },
  ] },
  sections: [{
    properties: { page: { margin: { top: 1200, bottom: 1200, left: 1200, right: 1200 } } },
    children: [
      new Paragraph({ style: 'Title', children: runs('Answers to Questions – Finance Report') }),
      new Paragraph({ spacing: { after: 240 },
        border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: '1F4E79', space: 4 } },
        children: runs('General Ledger Pivot page | Questions of 22.10.2026 | Checked against the report data (updated 21.10.2026) and rechecked on 23.10.2026', { color: '595959', size: 20 }) }),

      h('Summary'),
      table([600, 2600, 4400, 1900], [
        ['#', 'Question', 'Finding', 'Status'],
        ['1', 'All entities per column', 'Company option added to the Column selector (and to the Rows selector)', '**Done**'],
        ['2', 'Cleaning & maintenance line should be 0 according to SAP', 'JE 32085 (September accrual) is reversed by JE 32088 on 01.10.2026. October is not selected in the filter, so only the accrual is shown', 'Explanation – please include October'],
        ['3', 'Line appears "with no reason"', 'Same cause: 17,018 is the CEO Travel expenses line of the same JE 32085', 'Explanation'],
      ]),

      h('1. All entities per column'),
      bullet('We added **Company** to the **Column** selector (and to the **Rows** selector). Each entity can now be shown in its own column, side by side. The change is already available in the updated report.'),
      bullet('For this view, please use **Currency Type = System**. Local currencies differ between the entities (EUR for GmbH, USD for INC, etc.), so in Local mode the total adds up different currencies.'),
      bullet('**Question for you:** would you like Year and Company together (e.g. 2026 → GmbH / INC / LTD), or Company only? For now you can pick Company instead of Year and filter the year with the Year slicer.'),

      h('2. Cleaning & maintenance line (14,240)'),
      p('We reproduced your view exactly with these filters: ClientD AI GmbH, account 6032 | Audit & Financial, year 2026, Currency Type = System.'),
      p('**Source of the amount:** JE **32085** "other accruals 09.2026" (posting date 01.09.2026) includes the lines 603001 Accounting audit and tax services = 10,211.03 and 603002 Payroll services = 4,028.82. Together: 14,239.85.'),
      p('**The reversal:** JE **32088** "(Reversal) - 28686", dated 01.10.2026, reverses JE 32085 line by line. So for the full year 2026 the line nets to zero – exactly as in SAP.'),
      p('**Why the line appears in your view:** the Year filter shows "Multiple selections" – October is not selected, so the reversal is filtered out. For January–September this is correct: the accrual is indeed open at the end of September.'),
      table([3700, 2900, 2900], [
        ['Offset Account Name', 'Jan–Sep 2026 (your view)', 'Full year 2026'],
        ['Andreas Freitag', '136', '136'],
        ['Bakertilly', '9,657', '9,657'],
        ['Cleaning & maintenance', '14,240', '0'],
        ['Frankfurter Bett GmbH', '2,101', '2,101'],
        ['Other accrued expenses', '-4,568', '-4,568'],
        ['Other prepaid expenses', '-6,336', '-6,336'],
        ['Recruitment costs G&A', '6,336', '6,336'],
        ['Total', '21,565', '7,325'],
      ], { numCols: [1, 2], highlight: 3, totalLast: true }),

      h('3. Line appears "with no reason" (17,018)'),
      p('The row under the cursor is Cleaning & maintenance = **17,018**. The amount equals line **606208 CEO Travel expenses = 17,018.38** of the same JE 32085. The cause is the same as in question 2: the contra account recorded in SAP on the accrual JE, and October not being selected, so the reversal is not shown.'),

      h('Why Cleaning & maintenance appears as the offset account'),
      p('This is the real question behind questions 2 and 3:'),
      bullet('The **Offset Account** column in the report is SAP\'s own contra-account field on each journal line.'),
      bullet('For a multi-line journal entry, SAP stores **one** contra account per line.'),
      bullet('JE 32085 debits about 15 expense accounts and credits **203000 Other accrued expenses** (84,846.97) and **604002 Cleaning & maintenance** (2,654.87).'),
      bullet('SAP set 604002 as the contra account for **all** the debit lines. So utilities, CEO travel, audit, etc. all show Cleaning & maintenance as their offset, although the main counterpart is 203000.'),
      bullet('The report shows what SAP stores: the label is misleading, but **the amounts are correct**.'),
      p('**Option to change:** the report can show the main counter-account instead (the largest line on the opposite side – here 203000) rather than the SAP field. This changes the meaning of an existing column, so we will do it only with your approval.'),

      h('What we need from you'),
      num('Select October (or the full year) in the Year filter and check that the Cleaning & maintenance line disappears (total 7,325 in the question 2 view).'),
      num('Choose the layout for entities: Year + Company, or Company only.'),
      num('Decide whether to change the offset account logic to the main counter-account.'),
    ],
  }],
});

Packer.toBuffer(doc).then(b => fs.writeFileSync(OUT, b));
