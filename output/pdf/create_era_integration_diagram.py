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
W, H = 2200, 1050
PDF = OUT / 'era-eurotrex-integration.pdf'
SVG = OUT / 'era-eurotrex-integration.svg'
INK, MUTED, GOLD, BLUE = '#293D55', '#596877', '#E7C458', '#2D5DD3'
SAND, WHITE, LINE = '#F7F8FA', '#FFFFFF', '#D9E0E7'
c = canvas.Canvas(str(PDF), pagesize=(W, H))
c.setTitle('ERA and EuroTrex - proposed integration')
c.setAuthor('EuroTrex')
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-labelledby="title desc">',
       '<title id="title">ERA and EuroTrex integration</title>',
       '<desc id="desc">Proposed ERA integration. Mapy, OpenStreetMap and Waymarked Trails supply trail imports into an ERA central platform. Its central database holds authoritative trail and incident records. Assigned trail managers edit and approve their trails and manage incidents. EuroTrex includes both the Firebase backend and the Mobile App, grouped within one system boundary. EuroTrex Firebase pulls approved trails from the ERA Central Platform and supplies them to the Mobile App. The approved-trails arrow represents data flowing from ERA to EuroTrex. Incident reports flow from Mobile through Firebase to ERA, with status returning through Firebase to Mobile. Import connectors are proposed, not implemented.</desc>']

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


GREEN, GREEN_PALE = '#589775', '#E5F2E8'
ORANGE, ORANGE_PALE = '#CD7B35', '#FFF0E1'
rect(0,0,W,H,SAND)
rect(50,43,5,43,GOLD,radius=2)
text(74,77,'ERA + EuroTrex',38,True)
text(50,117,'Central trail platform & app integration',24,fill=MUTED)
text(2150,77,'PROPOSED',17,True,fill=MUTED,anchor='end')

# Import sources. No unverified live connectors are implied.
rect(50,275,280,390,WHITE,LINE,10)
icon('globe',75,301,34,color=INK)
text(123,327,'Map sources',26,True)
line([(75,350),(305,350)],LINE,1)
for y,title in [(385,'Mapy'),(475,'OSM'),(565,'Waymarked Trails')]:
    rect(70,y,240,60,'#EEF3F7',radius=6)
    text(190,y+38,title,23,True,anchor='middle')
line([(330,475),(530,475)],GREEN,2.8,True)
text(430,448,'Import trails',21,fill=GREEN,anchor='middle')

# ERA is the central system of record, with web-based management functions.
rect(530,180,650,785,WHITE,LINE,12)
rect(530,180,650,80,INK,radius=12)
rect(530,242,650,18,INK)
icon('globe',558,202,34,color=WHITE)
text(610,234,'ERA Central Platform',31,True,fill=WHITE)
rect(555,280,600,99,'#EEF3F7',radius=8)
icon('data',577,307,38,color=INK)
text(635,320,'Central Database',27,True)
text(635,352,'Authoritative trail and incident records',21,fill=MUTED)

def era_workflow(y,kind,title,steps,color,pale):
    rect(555,y,600,137,pale,radius=9)
    icon(kind,577,y+18,31,color=color)
    text(626,y+44,title,27,True)
    for x,label in zip([577,772,967],steps):
        rect(x,y+70,165,45,WHITE,radius=5)
        text(x+82.5,y+99,label,20,True,anchor='middle')
    for x in [748,943]:line([(x,y+92),(x+17,y+92)],color,1.8,True)

era_workflow(405,'route','Trail Management',['Import','Edit','Approve'],GREEN,GREEN_PALE)
era_workflow(600,'report','Incident Management',['Receive','Assign','Resolve'],ORANGE,ORANGE_PALE)

# Access is scoped to each manager's assigned trails.
rect(555,810,600,125,'#F5F3EC',radius=9)
icon('shield',577,831,34,color=INK)
text(626,855,'Trail managers',26,True)
text(577,891,'ERA assigns access by trail',22,fill=MUTED)
text(577,920,'Edit / approve trails and handle their incidents',21,fill=MUTED)
# Shared manager access branches to both management functions.
line([(555,872),(542,872),(542,475),(555,475)],MUTED,2,True)
line([(542,668),(555,668)],MUTED,2,True)

# EuroTrex contains both the delivery backend and the mobile client.
rect(1355,250,820,560,'#EEF3F7',LINE,12)
rect(1355,250,820,80,'#38516c',radius=12)
rect(1355,312,820,18,'#38516c')
text(1380,302,'EuroTrex',31,True,fill=WHITE)
# ERA owns the master records.
rect(1380,350,300,430,WHITE,LINE,10)
icon('cloud',1405,377,36,color=INK)
text(1458,405,'Firebase',28,True)
line([(1405,462),(1655,462)],LINE,1)
icon('bolt',1405,503,30,color=INK)
text(1450,527,'Integration API',23,True)
icon('data',1405,565,30,color=INK)
text(1450,589,'App data sync',23,True)

rect(1870,350,280,430,WHITE,LINE,10)
icon('mobile',1895,377,36,color=INK)
text(1943,405,'Mobile App',27,True)
line([(1895,432),(2125,432)],LINE,1)
for y,kind,label,color,pale in [(449,'route','Trail Maps & POI',GREEN,GREEN_PALE),(618,'report','Incidents',ORANGE,ORANGE_PALE)]:
    rect(1888,y,244,60,pale,radius=7)
    icon(kind,1900,y+15,29,color=color)
    text(1940,y+38,label,21,True)

def flow(x1,x2,y,label,color):
    text((x1+x2)/2,y-20,label,21,fill=color,anchor='middle')
    line([(x1,y),(x2,y)],color,2.8,True)
flow(1180,1380,490,'Approved trails',GREEN)
flow(1680,1870,490,'Trails',GREEN)
flow(1870,1680,650,'Incidents',ORANGE)
flow(1380,1180,650,'Incidents',ORANGE)
flow(1180,1380,720,'Status',ORANGE)
flow(1680,1870,720,'Status',ORANGE)

c.showPage();c.save()
svg.append('</svg>')
SVG.write_text('\n'.join(svg)+'\n')
print(PDF)
print(SVG)
