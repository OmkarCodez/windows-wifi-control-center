from xml.sax.saxutils import escape
from pathlib import Path

W,H=1536,1024
parts=[]
def add(s): parts.append(s)
def rect(x,y,w,h,fill='#ffffff',stroke='#aeb4bd',rx=12,sw=2):
    add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
def line(x1,y1,x2,y2,stroke='#aeb4bd',sw=2,dash=None):
    d=f' stroke-dasharray="{dash}"' if dash else ''
    add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}"{d}/>')
def txt(x,y,s,size=18,weight=400,fill='#252a31',anchor='start'):
    add(f'<text x="{x}" y="{y}" font-family="Inter, Arial, sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{escape(str(s))}</text>')
def card(x,y,w,h,title,subtitle=None):
    rect(x,y,w,h,'#ffffff','#aeb4bd',16,2)
    txt(x+22,y+34,title,20,700)
    if subtitle: txt(x+22,y+58,subtitle,13,400,'#68717d')
def pill(x,y,w,h,label,selected=False):
    rect(x,y,w,h,'#e5e7eb' if selected else '#f8f9fb','#aeb4bd',6,1)
    txt(x+w/2,y+h/2+6,label,14,600,'#252a31','middle')
def button(x,y,w,h,label,primary=False):
    rect(x,y,w,h,'#dfe3e8' if primary else '#ffffff','#8c949f',8,1.5)
    txt(x+w/2,y+h/2+6,label,14,600,'#252a31','middle')
def slider(x,y,w,percent=70):
    line(x,y,x+w,y,'#c5cbd3',7)
    line(x,y,x+w*percent/100,y,'#858e99',7)
    add(f'<circle cx="{x+w*percent/100}" cy="{y}" r="10" fill="#ffffff" stroke="#727b87" stroke-width="2"/>')

add(f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<title>Control Center — Low-fidelity wireframe</title>
<desc>Editable grayscale wireframe based on the supplied Control Center reference, containing the main dashboard and eight supporting widgets.</desc>
<rect width="{W}" height="{H}" fill="#f1f3f5"/>
''')
txt(40,28,'CONTROL CENTER · LOW-FIDELITY WIREFRAME',14,700,'#56606d')
txt(1496,28,'DESKTOP CANVAS  /  1536 × 1024',12,500,'#68717d','end')

# Main full dashboard
rect(40,48,500,914,'#fafbfc','#7f8995',18,2)
# Window header
for cx in [66,88,110]: add(f'<circle cx="{cx}" cy="78" r="7" fill="#cfd4da" stroke="#7f8995"/>')
txt(145,85,'Control Center',24,700)
button(474,62,42,30,'↻')
line(40,105,540,105,'#c8cdd4',1)

# Wi-Fi details
card(60,122,460,270,'Wi-Fi')
button(445,136,48,30,'↻')
# wifi indicator placeholder
add('<path d="M84 184 Q108 160 132 184 M92 194 Q108 178 124 194 M101 204 Q108 197 115 204" fill="none" stroke="#616b77" stroke-width="5" stroke-linecap="round"/>')
txt(150,183,'CONNECTED',12,700,'#68717d')
txt(150,211,'SSID  MyNetwork',17,600)
txt(150,239,'Channel  6',16)
txt(150,264,'Signal  99%',16)
txt(150,289,'Speed  270 Mbps',16)
txt(150,314,'Band  802.11n',16)
txt(150,339,'Security  WPA2-Personal',16)
txt(480,183,'18:54:47',13,500,'#68717d','end')
for i in range(11): pill(78+i*39,350,34,28,str(i+1),i==5)

# controls
card(60,408,460,112,'Controls')
txt(82,468,'Volume',15,600)
slider(180,462,292,70)
txt(82,501,'Display / Opacity',14,500,'#68717d')
txt(492,501,'⌄',22,500,'#68717d','end')

# media controls
rect(60,536,460,72,'#ffffff','#aeb4bd',16,2)
button(82,556,62,34,'|◀')
button(154,556,62,34,'▶ / II',True)
button(226,556,62,34,'▶|')
txt(324,579,'MIC  ●',14,600)
txt(424,579,'CAM  ●',14,600)

# speed test
card(60,624,460,192,'Speed Test')
button(448,637,48,30,'▶',True)
txt(82,685,'Download',14,500,'#68717d'); txt(230,685,'53.8 Mbps',16,700)
txt(82,713,'Upload',14,500,'#68717d'); txt(230,713,'54.9 Mbps',16,700)
txt(82,741,'Ping',14,500,'#68717d'); txt(230,741,'3.9 ms',16,700)
txt(82,769,'Jitter',14,500,'#68717d'); txt(230,769,'1.32 ms',16,700)
txt(82,797,'Server',14,500,'#68717d'); txt(230,797,'SpeedTest Server',15,600)

# device compact table at bottom main panel
card(60,832,460,110,'Devices')
button(444,844,50,28,'↻')
rect(78,882,424,28,'#e9ecf0','#c2c8d0',4,1)
for x in [219,360]: line(x,882,x,910,'#c2c8d0',1)
txt(148,902,'IP',13,600,'#3f4853','middle'); txt(289,902,'MAC',13,600,'#3f4853','middle'); txt(431,902,'Name',13,600,'#3f4853','middle')

# Right-side independent widgets
# WiFi tile
card(590,48,438,150,'Wi-Fi status')
rect(614,80,86,86,'#eef0f3','#c4cad2',18,1)
add('<path d="M632 117 Q657 93 682 117 M640 129 Q657 113 674 129 M650 140 Q657 133 664 140" fill="none" stroke="#59636f" stroke-width="6" stroke-linecap="round"/>')
txt(728,113,'MyNetwork',22,700)
txt(728,145,'Connected · 99% signal',15,500,'#68717d')
txt(990,115,'›',30,400,'#68717d','middle')

# speed test widget
card(590,220,438,300,'Speed Test')
button(950,238,56,38,'▶',True)
rect(620,283,178,112,'#f4f5f7','#c5cbd3',10,1)
rect(818,283,178,112,'#f4f5f7','#c5cbd3',10,1)
txt(709,315,'DOWNLOAD',12,700,'#68717d','middle'); txt(709,355,'53.8',30,700,'#252a31','middle'); txt(709,379,'Mbps',14,500,'#68717d','middle')
txt(907,315,'UPLOAD',12,700,'#68717d','middle'); txt(907,355,'54.9',30,700,'#252a31','middle'); txt(907,379,'Mbps',14,500,'#68717d','middle')
line(620,416,998,416,'#d3d7dd',1)
txt(638,455,'Ping',14,500,'#68717d'); txt(700,455,'3.9 ms',18,700)
txt(822,455,'Jitter',14,500,'#68717d'); txt(895,455,'1.32 ms',18,700)
txt(638,490,'Server',14,500,'#68717d'); txt(700,490,'SpeedTest Server',15,600)

# volume and display
card(1060,48,436,300,'System controls')
txt(1090,112,'Volume',18,600)
slider(1090,151,330,70); txt(1445,157,'70%',15,500,'#68717d','end')
line(1088,190,1468,190,'#d3d7dd',1)
txt(1090,242,'Display',18,600); txt(1450,242,'⌄',22,500,'#68717d','end')
line(1088,270,1468,270,'#d3d7dd',1)
txt(1090,318,'Opacity',18,600); txt(1450,318,'⌄',22,500,'#68717d','end')

# media bar
card(1060,372,436,148,'Media player')
button(1090,420,62,44,'|◀')
button(1164,412,68,60,'▶ / II',True)
button(1244,420,62,44,'▶|')
line(1322,405,1322,486,'#d3d7dd',1)
txt(1350,438,'MIC  ●',15,600)
txt(1350,468,'CAM  ●',15,600)

# devices table
card(590,544,600,262,'Connected devices')
button(1040,558,126,34,'↻  Scan')
rect(616,608,548,42,'#e9ecf0','#c2c8d0',6,1)
for x in [770,966]: line(x,608,x,650,'#c2c8d0',1)
txt(692,635,'IP ADDRESS',13,700,'#59636f','middle'); txt(868,635,'MAC ADDRESS',13,700,'#59636f','middle'); txt(1065,635,'NAME',13,700,'#59636f','middle')
for i,(ip,mac,name) in enumerate([('192.168.1.10','AA:BB:CC:DD:01','Laptop'),('192.168.1.11','AA:BB:CC:DD:02','Phone'),('192.168.1.12','AA:BB:CC:DD:03','Tablet')]):
    yy=688+i*38
    add(f'<circle cx="632" cy="{yy-5}" r="6" fill="#9aa3ae"/>')
    txt(650,yy,ip,14); txt(790,yy,mac,14); txt(1000,yy,name,14)
    if i<2: line(616,yy+14,1164,yy+14,'#e1e4e8',1)

# notification
card(1220,544,276,160,'Connection status')
add('<circle cx="1266" cy="623" r="28" fill="#e9edf1" stroke="#8b949f" stroke-width="2"/>')
txt(1266,631,'✓',30,700,'#59636f','middle')
txt(1310,615,'Connected',20,700)
txt(1310,644,'Wi-Fi is working',14,500,'#68717d')
txt(1310,664,'properly',14,500,'#68717d')

# Channels
card(590,830,600,132,'Wi-Fi channels')
txt(616,882,'Select channel',14,500,'#68717d')
for i in range(11): pill(616+i*49,898,40,34,str(i+1),i==5)

# small status tile
card(1220,738,276,224,'Quick status')
add('<path d="M1248 806 Q1274 780 1300 806 M1257 817 Q1274 800 1291 817 M1267 828 Q1274 821 1281 828" fill="none" stroke="#59636f" stroke-width="5" stroke-linecap="round"/>')
txt(1316,807,'MyNetwork',22,700)
txt(1316,837,'Connected',15,500,'#68717d')
txt(1248,890,'Signal strength',13,500,'#68717d')
rect(1248,905,216,12,'#e5e8ec','#c2c8d0',6,1); rect(1248,905,214,12,'#aeb6c0','#aeb6c0',6,1)
txt(1466,943,'99%',13,600,'#68717d','end')

# small annotation
txtdummy=''
add('</svg>')
svg='\n'.join(parts)
Path('/mnt/data/control-center-wireframe/01-control-center-wireframe.svg').write_text(svg,encoding='utf-8')
