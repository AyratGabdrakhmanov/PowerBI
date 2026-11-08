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
    new TextRun({ text: s.replace(/\*\*/g, ''), bold: s.startsWith('**') || extra.bold,
      rightToLeft: /[֐-׿]/.test(s), font: FONT, ...extra }));
}
const p = (t, o = {}) => new Paragraph({ bidirectional: true, alignment: AlignmentType.RIGHT,
  spacing: { after: 120 }, children: runs(t), ...o });
const h = (t, lvl = HeadingLevel.HEADING_1) => new Paragraph({ heading: lvl, bidirectional: true,
  alignment: AlignmentType.RIGHT, children: runs(t) });
const bullet = t => p(t, { numbering: { reference: 'b', level: 0 } });
const num = t => p(t, { numbering: { reference: 'n', level: 0 } });

function table(widths, rows, opts = {}) {
  const total = widths.reduce((a, b) => a + b, 0);
  return new Table({
    visuallyRightToLeft: true, width: { size: total, type: WidthType.DXA }, columnWidths: widths,
    rows: rows.map((r, i) => new TableRow({ tableHeader: i === 0, children: r.map((c, j) => {
      const head = i === 0, totalRow = opts.totalLast && i === rows.length - 1;
      const hl = opts.highlight && opts.highlight === i;
      return new TableCell({
        width: { size: widths[j], type: WidthType.DXA },
        shading: head ? { type: ShadingType.CLEAR, fill: '1F4E79', color: 'auto' }
          : hl ? { type: ShadingType.CLEAR, fill: 'FFF2CC', color: 'auto' }
          : totalRow ? { type: ShadingType.CLEAR, fill: 'DEEAF6', color: 'auto' } : undefined,
        margins: { top: 60, bottom: 60, left: 100, right: 100 },
        children: [(opts.numCols && opts.numCols.includes(j) && !head)
          ? new Paragraph({ alignment: AlignmentType.LEFT,
              children: runs(c, { bold: totalRow, rightToLeft: false }) })
          : new Paragraph({ bidirectional: true, alignment: AlignmentType.RIGHT,
              children: runs(c, { bold: head || totalRow, color: head ? 'FFFFFF' : undefined }) })],
      });
    }) })),
  });
}
const gap = () => new Paragraph({ children: [] });

const doc = new Document({
  styles: {
    default: { document: { run: { font: FONT, size: 22, rightToLeft: true } } },
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
      new Paragraph({ style: 'Title', bidirectional: true, alignment: AlignmentType.RIGHT,
        children: runs('תשובות לשאלות – דוח Finance') }),
      new Paragraph({ bidirectional: true, alignment: AlignmentType.RIGHT, spacing: { after: 240 },
        border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: '1F4E79', space: 4 } },
        children: runs('עמוד General Ledger Pivot | שאלות מתאריך 22.10.2026 | נבדק מול נתוני הדוח (עדכון 21.10.2026), ונבדק שוב ב-23.10.2026', { color: '595959', size: 20 }) }),

      h('סיכום'),
      table([600, 2600, 4400, 1900], [
        ['#', 'שאלה', 'ממצא', 'סטטוס'],
        ['1', 'כל החברות בעמודות', 'נוספה אפשרות Company לבורר העמודות (וגם לבורר השורות)', '**בוצע**'],
        ['2', 'שורת Cleaning & maintenance צריכה להיות 0 לפי SAP', 'פקודת יומן 32085 (הפרשה לספטמבר) מבוטלת בפקודה 32088 ב-01.10.2026. חודש אוקטובר לא נבחר במסנן, לכן מוצגת רק ההפרשה', 'הסבר – יש לבחור גם את אוקטובר'],
        ['3', 'שורה שמופיעה "ללא סיבה"', 'אותה סיבה: 17,018 היא שורת CEO Travel expenses של אותה פקודה 32085', 'הסבר'],
      ]),

      h('1. כל החברות בעמודות'),
      bullet('הוספנו את **Company** לבורר **Column** (וגם לבורר **Rows**). כעת ניתן להציג כל חברה בעמודה נפרדת, זו לצד זו. השינוי כבר זמין בדוח המעודכן.'),
      bullet('בתצוגה זו מומלץ לבחור **Currency Type = System**. המטבעות המקומיים שונים בין החברות (EUR ב-GmbH, USD ב-INC וכו\'), ובמצב Local הסכום הכולל מחבר מטבעות שונים.'),
      bullet('**שאלה אלייך:** האם להציג שנה וחברה יחד (למשל 2026 ← GmbH / INC / LTD), או חברה בלבד? כרגע ניתן לבחור Company במקום Year, ולסנן את השנה בסלייסר Year.'),

      h('2. שורת Cleaning & maintenance (14,240)'),
      p('שחזרנו את התצוגה שלך במדויק עם המסננים: ClientD AI GmbH, חשבון 6032 | Audit & Financial, שנת 2026, Currency Type = System.'),
      p('**מקור הסכום:** פקודת יומן **32085** "other accruals 09.2026" (תאריך רישום 01.09.2026) כוללת את השורות 603001 Accounting audit and tax services = 10,211.03 ו-603002 Payroll services = 4,028.82. יחד: 14,239.85.'),
      p('**הביטול:** פקודת יומן **32088** "(Reversal) - 28686" מתאריך 01.10.2026 מבטלת את פקודה 32085 שורה אחר שורה. לכן לכל שנת 2026 השורה מתאפסת – בדיוק כמו ב-SAP.'),
      p('**למה השורה מופיעה אצלך:** במסנן Year מופיע "Multiple selections" – חודש אוקטובר לא נבחר, ולכן פקודת הביטול מסוננת החוצה. עבור ינואר–ספטמבר זו התנהגות נכונה: ההפרשה אכן פתוחה בסוף ספטמבר.'),
      table([3700, 2900, 2900], [
        ['Offset Account Name', 'ינואר–ספטמבר 2026 (התצוגה שלך)', 'כל שנת 2026'],
        ['Andreas Freitag', '136', '136'],
        ['Bakertilly', '9,657', '9,657'],
        ['Cleaning & maintenance', '14,240', '0'],
        ['Frankfurter Bett GmbH', '2,101', '2,101'],
        ['Other accrued expenses', '-4,568', '-4,568'],
        ['Other prepaid expenses', '-6,336', '-6,336'],
        ['Recruitment costs G&A', '6,336', '6,336'],
        ['סה"כ', '21,565', '7,325'],
      ], { numCols: [1, 2], highlight: 3, totalLast: true }),

      h('3. שורה שמופיעה "ללא סיבה" (17,018)'),
      p('השורה שעליה עומד הסמן היא Cleaning & maintenance = **17,018**. הסכום זהה לשורה **606208 CEO Travel expenses = 17,018.38** של אותה פקודת יומן 32085. הסיבה זהה לשאלה 2: החשבון הנגדי שנרשם ב-SAP בפקודת ההפרשה, ובנוסף חודש אוקטובר לא נבחר, ולכן הביטול לא מוצג.'),

      h('למה Cleaning & maintenance מופיע כחשבון נגדי'),
      p('זו השאלה המהותית שמאחורי שאלות 2 ו-3:'),
      bullet('עמודת **Offset Account** בדוח היא שדה החשבון הנגדי של SAP עצמו בכל שורת פקודה.'),
      bullet('בפקודת יומן מרובת שורות, SAP שומר חשבון נגדי **אחד** לכל שורה.'),
      bullet('פקודה 32085 מחייבת כ-15 חשבונות הוצאה, ומזכה את **203000 Other accrued expenses** (84,846.97) ואת **604002 Cleaning & maintenance** (2,654.87).'),
      bullet('SAP הגדיר את 604002 כחשבון הנגדי של **כל** שורות החובה. לכן חשמל, נסיעות מנכ"ל, ביקורת וכו\' מציגים Cleaning & maintenance כחשבון נגדי, אף שהצד הנגדי העיקרי הוא 203000.'),
      bullet('הדוח מציג את מה ש-SAP שומר: התווית מטעה, אבל **הסכומים נכונים**.'),
      p('**אפשרות לשינוי:** ניתן להציג בדוח את החשבון הנגדי העיקרי (השורה הגדולה ביותר בצד הנגדי – כאן 203000) במקום השדה של SAP. מדובר בשינוי משמעות של עמודה קיימת, ולכן נבצע אותו רק באישורך.'),

      h('מה נדרש ממך'),
      num('לבחור את אוקטובר (או את כל השנה) במסנן Year ולוודא ששורת Cleaning & maintenance נעלמת (סה"כ 7,325 בתצוגה של שאלה 2).'),
      num('לבחור תצוגה לחברות: שנה + חברה, או חברה בלבד.'),
      num('להחליט האם לשנות את לוגיקת החשבון הנגדי לחשבון הנגדי העיקרי.'),
    ],
  }],
});

Packer.toBuffer(doc).then(b => fs.writeFileSync(OUT, b));
