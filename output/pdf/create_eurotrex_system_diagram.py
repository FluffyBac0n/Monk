from pathlib import Path
from html import escape
import math
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
pdfmetrics.registerFont(TTFont("Diagram", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Diagram-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))

OUT = Path(__file__).parent
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1800, 1000
PDF = OUT / 'eurotrex-system-overview.pdf'
SVG = OUT / 'eurotrex-system-overview.svg'
INK, MUTED, GOLD, BLUE = '#293D55', '#596877', '#E7C458', '#2D5DD3'
SAND, WHITE, LINE = '#F7F8FA', '#FFFFFF', '#D9E0E7'
c = canvas.Canvas(str(PDF), pagesize=(W, H))
c.setTitle('EuroTrex - system architecture and workflows')
c.setAuthor('EuroTrex')
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-labelledby="title desc">',
       '<title id="title">EuroTrex system overview</title>',
       '<desc id="desc">Mobile App on the left, Firebase backend in the middle, and Website functions on the right. Management workflows belong to the Website; Firebase provides shared data, storage and access. Trail Management flows from Website through Backend to Mobile. Incidents flow from Mobile through Backend to Website, with feedback returning from Website through Backend to Mobile. Host Portal flows one way from Website through Backend to Mobile.</desc>']

def rect(x, y, w, h, fill, stroke=None, radius=0):
    c.setFillColor(HexColor(fill))
    c.setStrokeColor(HexColor(stroke or fill))
    c.setLineWidth(1.3)
    c.roundRect(x, H-y-h, w, h, radius, fill=1, stroke=bool(stroke))
    svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke or "none"}" stroke-width="1.3"/>')

def text(x, y, value, size=20, bold=False, fill=INK, anchor='start'):
    font = 'Diagram-Bold' if bold else 'Diagram'
    c.setFillColor(HexColor(fill)); c.setFont(font, size)
    {'start':c.drawString, 'middle':c.drawCentredString, 'end':c.drawRightString}[anchor](x,H-y,value)
    svg.append(f'<text x="{x}" y="{y}" font-family="Arial, Helvetica, sans-serif" font-size="{size}" font-weight="{700 if bold else 400}" letter-spacing="0" word-spacing="0" font-kerning="normal" fill="{fill}" text-anchor="{anchor}">{escape(value)}</text>')

def line(points, color=LINE, width=2, arrow=False):
    c.setStrokeColor(HexColor(color)); c.setLineWidth(width)
    p=c.beginPath();p.moveTo(points[0][0],H-points[0][1])
    for x,y in points[1:]:p.lineTo(x,H-y)
    c.drawPath(p)
    svg.append(f'<polyline points="{" ".join(f"{x},{y}" for x,y in points)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"/>')
    if arrow:
        x,y=points[-1];px,py=points[-2];a=math.atan2(y-py,x-px);length=10;spread=.48
        pts=[(x,y),(x-length*math.cos(a-spread),y-length*math.sin(a-spread)),(x-length*math.cos(a+spread),y-length*math.sin(a+spread))]
        c.setFillColor(HexColor(color));p=c.beginPath();p.moveTo(pts[0][0],H-pts[0][1])
        for xx,yy in pts[1:]:p.lineTo(xx,H-yy)
        p.close();c.drawPath(p,fill=1,stroke=0)
        svg.append(f'<polygon points="{" ".join(f"{xx:.2f},{yy:.2f}" for xx,yy in pts)}" fill="{color}"/>')

def tag(x,y,label,width):
    rect(x-width/2,y-20,width,31,SAND)
    text(x,y,label,18,anchor='middle',fill=MUTED)


def icon(kind,x,y,size=44,color=BLUE):
    drawings={
      'mobile': [('M',14,3),('L',34,3),('C',37,3,39,5,39,8),('L',39,40),('C',39,43,37,45,34,45),('L',14,45),('C',11,45,9,43,9,40),('L',9,8),('C',9,5,11,3,14,3),('Z',),('M',20,38),('L',28,38)],
      'globe': [('M',44,24),('C',44,35,35,44,24,44),('C',13,44,4,35,4,24),('C',4,13,13,4,24,4),('C',35,4,44,13,44,24),('Z',),('M',4,24),('L',44,24),('M',24,4),('C',9,15,9,33,24,44),('C',39,33,39,15,24,4),('Z',)],
      'home': [('M',3,21),('L',24,4),('L',45,21),('M',9,18),('L',9,44),('L',39,44),('L',39,18),('M',19,44),('L',19,29),('L',29,29),('L',29,44),('M',16,21),('L',16,24),('M',32,21),('L',32,24)],
      'cloud': [('M',13,37),('C',-1,37,-1,19,12,18),('C',12,2,36,0,39,18),('C',51,18,52,37,39,37),('Z',),('M',17,45),('L',17,30),('M',31,45),('L',31,30)],
      'shield': [('M',24,3),('L',41,10),('L',41,23),('C',41,33,34,40,24,46),('C',14,40,7,33,7,23),('L',7,10),('Z',),('M',15,24),('L',22,31),('L',34,17)],
      'bolt': [('M',28,3),('L',10,28),('L',23,28),('L',20,45),('L',39,19),('L',26,19),('Z',)],
      'data': [('M',6,12),('C',6,1,42,1,42,12),('C',42,23,6,23,6,12),('M',6,12),('L',6,36),('C',6,47,42,47,42,36),('L',42,12),('M',6,24),('C',6,35,42,35,42,24)],
      'route': [('M',8,40),('C',38,44,40,26,24,26),('C',8,26,10,8,37,8),('M',8,36),('L',8,44),('M',33,4),('L',37,8),('L',33,12)],
      'report': [('M',12,4),('L',32,4),('L',40,12),('L',40,44),('L',8,44),('L',8,4),('Z',),('M',16,19),('L',32,19),('M',16,27),('L',32,27),('M',16,35),('L',26,35)],
      'folder': [('M',4,40),('L',4,10),('L',20,10),('L',25,16),('L',44,16),('L',44,40),('Z',)],
    }
    commands=drawings[kind];scale=size/48
    c.saveState();c.translate(x,H-y);c.scale(scale,-scale);c.setStrokeColor(HexColor(color));c.setLineWidth(2.4);c.setLineCap(1);c.setLineJoin(1)
    p=c.beginPath();svg_d=[]
    for cmd in commands:
      op,*v=cmd;svg_d.append(op+' '+ ' '.join(map(str,v)))
      if op=='M':p.moveTo(*v)
      elif op=='L':p.lineTo(*v)
      elif op=='C':p.curveTo(*v)
      else:p.close()
    c.drawPath(p,stroke=1,fill=0);c.restoreState()
    svg.append(f'<path d="{" ".join(svg_d)}" transform="translate({x} {y}) scale({scale})" fill="none" stroke="{color}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')


def system_card(x,y,title,eyebrow,kind,rows,height=210):
    rect(x,y,340,height,WHITE,LINE,8)
    icon(kind,x+25,y+53,36,color=INK)
    text(x+25,y+30,eyebrow,13,True,fill=MUTED)
    text(x+77,y+81,title,27,True)
    for i,row in enumerate(rows):text(x+25,y+125+i*29,row,20,fill=MUTED)


def exchange(x1,x2,y,rows):
    centre=(x1+x2)/2
    for i,row in enumerate(rows):text(centre,y-44+i*25,row,20,anchor='middle',fill=MUTED)
    line([(x1,y),(x2,y)],'#778A9E',2,True)


def workflow(y,kind,title,steps,output):
    icon(kind,650,y,29,color=BLUE)
    text(693,y+24,title,23,True)
    centres=[714,900,1086]
    widths=[145,150,130]
    for x,label,w in zip(centres,steps,widths):
        rect(x-w/2,y+49,w,43,'#EEF3F9',radius=5)
        text(x,y+77,label,18,True,anchor='middle')
    for left,right in [(788,822),(976,1016)]:line([(left,y+70),(right,y+70)],'#8C9BAB',1.5,True)
    text(650,y+126,output,18,fill=MUTED)


GREEN, GREEN_PALE = '#589775', '#E5F2E8'
ORANGE, ORANGE_PALE = '#CD7B35', '#FFF0E1'
ACCOM, ACCOM_PALE = '#5188BB', '#E8F1FB'

rect(0,0,W,H,SAND)
rect(60,44,5,43,GOLD,radius=2)
text(83,77,'EuroTrex',38,True)
text(60,115,'System architecture & workflows',23,fill=MUTED)

# Mobile and Website share header typography, spacing, icon size and divider.
rect(60,180,340,730,WHITE,LINE,10)
icon('mobile',90,207,36,color=INK)
text(141,236,'Mobile App',30,True)
line([(90,262),(370,262)],LINE,1)
for y,kind,rows,color,pale in [
    (284,'route',['Trail Maps & POI'],GREEN,GREEN_PALE),
    (479,'report',['Incidents'],ORANGE,ORANGE_PALE),
    (689,'home',['Accommodations'],ACCOM,ACCOM_PALE)]:
    rect(80,y,300,139,pale,radius=9)
    icon(kind,95,y+54,30,color=color)
    for i,label in enumerate(rows):
        text(141,y+63+i*26 if len(rows)>1 else y+77,label,20,True)

# Shared backend remains neutral: it is infrastructure, not a management UI.
rect(620,250,360,600,WHITE,LINE,10)
rect(620,250,360,100,INK,radius=10)
rect(620,330,360,20,INK)
icon('cloud',647,275,39,color=WHITE)
text(704,292,'Firebase',30,True,fill=WHITE)
text(704,323,'Backend',19,fill='#D5DFEA')
for y,kind,title,sub in [(403,'data','Firestore','Shared data'),(538,'folder','Storage','Photos and files'),(673,'shield','Auth + Functions','Access and APIs')]:
    icon(kind,653,y,33,color=INK)
    text(706,y+25,title,23,True)
    text(706,y+57,sub,18,fill=MUTED)

rect(1230,180,510,730,WHITE,LINE,10)
icon('globe',1260,207,36,color=INK)
text(1311,236,'Website',30,True)
line([(1260,262),(1710,262)],LINE,1)

def website_workflow(y,kind,title,steps,color,pale):
    rect(1248,y-16,474,139,pale,radius=9)
    icon(kind,1265,y,29,color=color)
    text(1308,y+24,title,25,True)
    for x,label in zip([1265,1420,1575],steps):
        rect(x,y+51,130,46,WHITE,radius=5)
        text(x+65,y+80,label,18,True,fill=INK,anchor='middle')
    line([(1398,y+74),(1415,y+74)],color,1.7,True)
    line([(1553,y+74),(1570,y+74)],color,1.7,True)

website_workflow(300,'route','Trail Management',['Save draft','Verify','Publish'],GREEN,GREEN_PALE)
website_workflow(495,'report','Incident Management',['Receive','Review','Update status'],ORANGE,ORANGE_PALE)
website_workflow(705,'home','Host Portal',['Submit listing','Review','Approve'],ACCOM,ACCOM_PALE)

def flow(x1,x2,y,rows,color):
    centre=(x1+x2)/2
    for i,row in enumerate(rows):
        text(centre,y-18-(len(rows)-1-i)*25,row,20,anchor='middle',fill=color)
    line([(x1,y),(x2,y)],color,2.6,True)

# Separate trail and accommodation reads preserve the colour of each complete flow.
flow(1230,980,374,['Trail updates'],GREEN)
flow(620,400,374,['Trails'],GREEN)
flow(620,400,779,['Accommodations'],ACCOM)
flow(400,620,540,['Incident reports','and photos'],ORANGE)
flow(980,1230,540,['Incident reports'],ORANGE)
flow(1230,980,615,['Status'],ORANGE)
flow(620,400,615,['Status'],ORANGE)
flow(1230,980,779,['Accommodation','updates'],ACCOM)

c.showPage();c.save()
svg.append('</svg>')
SVG.write_text('\n'.join(svg)+'\n')
print(PDF)
print(SVG)
