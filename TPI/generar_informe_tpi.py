"""Genera TPI/TPI_U4_U8_Informe_Tecnico.pdf desde el Markdown del informe."""
from pathlib import Path
import re
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,
                                TableStyle, PageBreak, Preformatted)

HERE = Path(__file__).resolve().parent
OUT = HERE / 'TPI_U4_U8_Informe_Tecnico.pdf'
MD = HERE / 'INFORME_TECNICO_U4_U8.md'

FONT = Path('/usr/share/fonts/liberation')
if (FONT / 'LiberationSans-Regular.ttf').exists():
    reg, bold, mono = 'LiberationSans-Regular.ttf', 'LiberationSans-Bold.ttf', 'LiberationMono-Regular.ttf'
else:
    FONT = Path(r'C:\Windows\Fonts')
    reg, bold, mono = 'arial.ttf', 'arialbd.ttf', 'cour.ttf'
pdfmetrics.registerFont(TTFont('Sans', str(FONT / reg)))
pdfmetrics.registerFont(TTFont('SansB', str(FONT / bold)))
pdfmetrics.registerFont(TTFont('Mono', str(FONT / mono)))

NAVY = colors.HexColor('#172534')
BLUE = colors.HexColor('#2370A0')
PALE = colors.HexColor('#F2F5F7')
GRAY = colors.HexColor('#E4E8EB')
LINE = colors.HexColor('#BAC4CC')
TEXT = colors.HexColor('#22313E')
DIM = colors.HexColor('#52616D')

ss = getSampleStyleSheet()
ss.add(ParagraphStyle(name='CTop', fontName='SansB', fontSize=14, leading=18,
                      alignment=TA_CENTER, textColor=colors.black))
ss.add(ParagraphStyle(name='CSmall', fontName='Sans', fontSize=10.5, leading=14,
                      alignment=TA_CENTER, textColor=colors.black))
ss.add(ParagraphStyle(name='CTitle', fontName='SansB', fontSize=21, leading=26,
                      alignment=TA_CENTER, textColor=colors.black))
ss.add(ParagraphStyle(name='CSub', fontName='Sans', fontSize=12, leading=17,
                      alignment=TA_CENTER, textColor=colors.black))
ss.add(ParagraphStyle(name='H1', fontName='SansB', fontSize=12.5, leading=15,
                      textColor=NAVY, spaceBefore=6, spaceAfter=3))
ss.add(ParagraphStyle(name='H2', fontName='SansB', fontSize=9.4, leading=11.5,
                      textColor=BLUE, spaceBefore=5, spaceAfter=2))
ss.add(ParagraphStyle(name='Body', fontName='Sans', fontSize=8.1, leading=10.0,
                      textColor=TEXT, spaceAfter=3))
ss.add(ParagraphStyle(name='Cell', fontName='Sans', fontSize=6.9, leading=8.1,
                      textColor=TEXT))
ss.add(ParagraphStyle(name='CellH', fontName='SansB', fontSize=6.9, leading=8.1,
                      textColor=NAVY))
ss.add(ParagraphStyle(name='CodeTPI', fontName='Mono', fontSize=6.2, leading=7.4,
                      textColor=TEXT))

def inline(t):
    t = (t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'`(.+?)`', r'<font name="Mono" size="7.3">\1</font>', t)
    return t

def p(t, style='Body'):
    return Paragraph(inline(t), ss[style])

def h1(t):
    return Table([[p(t, 'H1')]], colWidths=[17.8 * cm], style=TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), GRAY),
        ('LINEBELOW', (0, 0), (-1, -1), .35, LINE),
        ('LEFTPADDING', (0, 0), (-1, -1), 7), ('RIGHTPADDING', (0, 0), (-1, -1), 7),
        ('TOPPADDING', (0, 0), (-1, -1), 2), ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))

def grid(rows):
    n = max(len(r) for r in rows)
    rows = [r + [''] * (n - len(r)) for r in rows]
    cells = [[p(v, 'CellH' if i == 0 else 'Cell') for v in row]
             for i, row in enumerate(rows)]
    t = Table(cells, colWidths=[17.8 / n * cm] * n, repeatRows=1, hAlign='LEFT')
    st = [('GRID', (0, 0), (-1, -1), .35, LINE), ('VALIGN', (0, 0), (-1, -1), 'TOP'),
          ('BACKGROUND', (0, 0), (-1, 0), GRAY),
          ('LEFTPADDING', (0, 0), (-1, -1), 3), ('RIGHTPADDING', (0, 0), (-1, -1), 3),
          ('TOPPADDING', (0, 0), (-1, -1), 2), ('BOTTOMPADDING', (0, 0), (-1, -1), 2)]
    for i in range(2, len(rows), 2):
        st.append(('BACKGROUND', (0, i), (-1, i), PALE))
    t.setStyle(TableStyle(st))
    return t

def code(text):
    box = Table([[Preformatted(text, ss['CodeTPI'])]], colWidths=[17.8 * cm])
    box.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), PALE), ('BOX', (0, 0), (-1, -1), .4, LINE),
        ('LEFTPADDING', (0, 0), (-1, -1), 5), ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    return box

def decor(canvas, doc):
    canvas.saveState()
    if doc.page > 1:
        w, h = A4
        canvas.setFillColor(NAVY)
        canvas.rect(1.5 * cm, h - 1.2 * cm, w - 3.0 * cm, .34 * cm, fill=1, stroke=0)
        canvas.setFillColor(colors.white)
        canvas.setFont('SansB', 7.3)
        canvas.drawString(1.7 * cm, h - 1.07 * cm,
                          'FOOD STORE  |  TPI  |  UNIDADES 4 A 8')
        canvas.setStrokeColor(LINE)
        canvas.line(1.5 * cm, 1.1 * cm, w - 1.5 * cm, 1.1 * cm)
        canvas.setFillColor(DIM)
        canvas.setFont('Sans', 7)
        canvas.drawRightString(w - 1.5 * cm, .78 * cm, f'Página {doc.page}')
    canvas.restoreState()

story = [
    Spacer(1, 2.0 * cm),
    p('UNIVERSIDAD TECNOLÓGICA NACIONAL', 'CTop'),
    p('Tecnicatura Universitaria en Programación', 'CSmall'),
    Spacer(1, 2.2 * cm),
    p('TRABAJO PRÁCTICO INTEGRADOR', 'CTitle'),
    p('Food Store - Segunda entrega', 'CSub'),
    p('Capa de datos: Unidades 4 a 8', 'CSub'),
    Spacer(1, 1.6 * cm),
    p('**PostgreSQL 18.6 · MongoDB 8.0.34 · SQLite 3.54**', 'CSmall'),
    Spacer(1, 1.8 * cm),
    p('Materia: Base de Datos II', 'CSmall'),
    p('Carrera: Tecnicatura Universitaria en Programación (UTN)', 'CSmall'),
    Spacer(1, 1.3 * cm),
    p('**Integrantes:**', 'CSmall'),
    p('Lemus Nahuel', 'CSmall'),
    p('Anglat Juan', 'CSmall'),
    p('Elias Juan Cruz', 'CSmall'),
    Spacer(1, 1.1 * cm),
    p('Repositorio: github.com/hero21lb/foodstore-gestor', 'CSmall'),
    Spacer(1, 1.0 * cm),
    p('Año 2026', 'CSmall'),
    PageBreak(),
]

lines = MD.read_text(encoding='utf-8').splitlines()
i = 0
para = []
def flush():
    global para
    if para:
        story.append(p(' '.join(x.strip() for x in para)))
        para = []

while i < len(lines):
    line = lines[i]
    if line.startswith('```'):
        flush()
        i += 1
        buf = []
        while i < len(lines) and not lines[i].startswith('```'):
            buf.append(lines[i]); i += 1
        story.append(code('\n'.join(buf)))
        story.append(Spacer(1, .12 * cm))
        i += 1
        continue
    if line.startswith('|'):
        flush()
        rows = []
        while i < len(lines) and lines[i].startswith('|'):
            raw = [c.strip() for c in lines[i].strip().strip('|').split('|')]
            if not all(re.fullmatch(r':?-{2,}:?', c) for c in raw if c):
                rows.append(raw)
            i += 1
        if rows:
            story.append(grid(rows))
            story.append(Spacer(1, .12 * cm))
        continue
    if line.startswith('# '):
        flush()
        if not line[2:].startswith('TPI Food Store'):
            story.append(h1(line[2:].strip())); story.append(Spacer(1, .1 * cm))
    elif line.startswith('## '):
        flush(); story.append(p(line[3:].strip(), 'H2'))
    elif line.startswith('### '):
        flush(); story.append(p(line[4:].strip(), 'H2'))
    elif line.startswith('- '):
        flush(); story.append(p('• ' + line[2:].strip()))
    elif line.strip() == '':
        flush()
    elif line.strip() == '---':
        flush()
    else:
        para.append(line)
    i += 1
flush()

doc = SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=1.5 * cm,
                        rightMargin=1.5 * cm, topMargin=1.5 * cm,
                        bottomMargin=1.3 * cm,
                        title='TPI Food Store - Unidades 4 a 8',
                        author='Lemus Nahuel, Anglat Juan, Elias Juan Cruz')
doc.build(story, onFirstPage=decor, onLaterPages=decor)
print(OUT)
