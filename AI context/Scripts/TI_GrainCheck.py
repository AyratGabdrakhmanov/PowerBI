# TI_GrainCheck.py
# Writes a DAX query that checks every reference TI.* UDF (TI_UDF.tmdl) at 5 grains - day, month, quarter, year,
# a range across quarters - against expected periods computed here from explicit date ranges (CG semantics: to-date
# functions follow the last period in context). Base measure [Sales Amount]; last year = current year - 1.
# Usage: python -I TI_GrainCheck.py <out.dax>  ->  QueryOpenModel.ps1 -QueryFile <out.dax> -Port <port>; every row Pass = True.
# Results 2026-10-31 on TI UDF Sample: 210 / 210 pass.
#
# Change log
# 2026-10-31  Created.

import calendar, datetime as dt, sys
LY = dt.date.today().year - 1
D = dt.date

def eom(d): return D(d.year, d.month, calendar.monthrange(d.year, d.month)[1])
def mstart(d): return D(d.year, d.month, 1)
def qstart(d): return D(d.year, 3 * ((d.month - 1) // 3) + 1, 1)
def qend(d): return eom(D(d.year, qstart(d).month + 2, 1))
def addm(d, n, to_eom=False):
    y, m = divmod(d.month - 1 + n, 12); y += d.year; m += 1
    last = calendar.monthrange(y, m)[1]
    return D(y, m, last if to_eom else min(d.day, last))
def shift(r, n):   # DATEADD on a contiguous range: an end on a month end stays on the month end
    a, b = r
    return (addm(a, n, a.day == 1 and False), addm(b, n, b == eom(b)))

GRAINS = {
    'Day 15 May':   (D(LY, 5, 15), D(LY, 5, 15)),
    'Month May':    (D(LY, 5, 1),  D(LY, 5, 31)),
    'Quarter Q2':   (D(LY, 4, 1),  D(LY, 6, 30)),
    'Year':         (D(LY, 1, 1),  D(LY, 12, 31)),
    'Range Feb-Apr': (D(LY, 2, 1), D(LY, 4, 30)),
}

def blocks(sel):
    L = sel[1]
    mtd, qtd, ytd = (mstart(L), L), (qstart(L), L), (D(L.year, 1, 1), L)
    pm_start = addm(mstart(L), -1)
    pq_start = addm(qstart(L), -3)
    return {
        'MTD': mtd, 'QTD': qtd, 'YTD': ytd,
        'PM': shift(mtd, -1), 'PMTD': shift(mtd, -1),
        'PQ': shift(qtd, -3), 'PQTD': shift(qtd, -3),
        'PY': shift(sel, -12), 'PYTD': shift(ytd, -12), 'PYMTD': shift(mtd, -12), 'PYQTD': shift(qtd, -12),
        'PMC': (pm_start, eom(pm_start)), 'PQC': (pq_start, qend(pq_start)),
        'PYC': (D(sel[0].year - 1, 1, 1), D(sel[0].year - 1, 12, 31)),
        'PYMC': (D(L.year - 1, L.month, 1), eom(D(L.year - 1, L.month, 1))),
        'PYQC': (qstart(D(L.year - 1, L.month, 1)), qend(D(L.year - 1, L.month, 1))),
    }

# comparison: (current block or 'SEL', previous block, guard on current)
CMP = {
    'MTDvsPMTD': ('MTD', 'PMTD', False), 'QTDvsPQTD': ('QTD', 'PQTD', False), 'YTDvsPYTD': ('YTD', 'PYTD', True),
    'MTDvsPYMTD': ('MTD', 'PYMTD', True), 'QTDvsPYQTD': ('QTD', 'PYQTD', True),
    'MTDvsFullPM': ('MTD', 'PMC', False), 'QTDvsFullPQ': ('QTD', 'PQC', False), 'YTDvsFullPY': ('YTD', 'PYC', True),
    'MOM': ('MTD', 'PM', False), 'QOQ': ('QTD', 'PQ', False), 'YOY': ('SEL', 'PY', True),
    'MTDvsFullPYM': ('MTD', 'PYMC', True), 'QTDvsFullPYQ': ('QTD', 'PYQC', True),
}

def dd(d): return f"DATE ( {d.year}, {d.month}, {d.day} )"
def S(r): return f"CALCULATE ( [Sales Amount], DATESBETWEEN ( 'Calendar'[Date], {dd(r[0])}, {dd(r[1])} ) )"

rows = []
for g, sel in GRAINS.items():
    ctx = f"DATESBETWEEN ( 'Calendar'[Date], {dd(sel[0])}, {dd(sel[1])} )"
    b = blocks(sel)
    for name, r in b.items():
        rows.append(f'( "TI.{name}", "{g}", "{r[0]:%d.%m.%y}-{r[1]:%d.%m.%y}", {S(r)}, CALCULATE ( TI.{name} ( [Sales Amount] ), {ctx} ) )')
    for name, (c, p, guard) in CMP.items():
        cr = sel if c == 'SEL' else b[c]
        cur, prev = S(cr), S(b[p])
        g_cur = f" * DIVIDE ( {cur}, {cur} )" if guard else ""
        exp_abs = f"( {cur} - {prev} ) * DIVIDE ( {prev}, {prev} ){g_cur}"
        exp_pct = f"DIVIDE ( {cur} - {prev}, ABS ( {prev} ) ){g_cur}"
        lbl = f"{cr[0]:%d.%m}-{cr[1]:%d.%m} vs {b[p][0]:%d.%m.%y}-{b[p][1]:%d.%m.%y}"
        rows.append(f'( "TI.{name}", "{g}", "{lbl}", {exp_abs}, CALCULATE ( TI.{name} ( [Sales Amount] ), {ctx} ) )')
        rows.append(f'( "TI.{name}Pct", "{g}", "{lbl}", {exp_pct}, CALCULATE ( TI.{name}Pct ( [Sales Amount] ), {ctx} ) )')

q = ("EVALUATE\nVAR __T = {\n    " + "\n    , ".join(rows) + "\n}\nRETURN\n    SELECTCOLUMNS ( __T, \"Function\", [Value1], \"Grain\", [Value2], \"Expected periods\", [Value3]"
     ", \"Expected\", [Value4], \"Actual\", [Value5]"
     ", \"Pass\", IF ( ISBLANK ( [Value4] ), ISBLANK ( [Value5] ), NOT ISBLANK ( [Value5] ) && ABS ( [Value4] - [Value5] ) < 0.0001 ) )\n")
open(sys.argv[1], 'w', encoding='utf-8').write(q)
print(len(rows), 'rows')
