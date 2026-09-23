#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 1536, 969
ROOT = Path(__file__).resolve().parent

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]
BOLD_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]

def pick_font(candidates, size):
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

REG = pick_font(FONT_CANDIDATES, 46)
SM = pick_font(FONT_CANDIDATES, 32)
XS = pick_font(FONT_CANDIDATES, 24)
BOLD = pick_font(BOLD_CANDIDATES, 64)
BOLD2 = pick_font(BOLD_CANDIDATES, 42)
BIG = pick_font(BOLD_CANDIDATES, 110)

def gradient(c1, c2):
    im = Image.new("RGB", (W, H), c1)
    d = ImageDraw.Draw(im)
    for x in range(W):
        t = x / (W - 1)
        c = tuple(round(c1[i] * (1 - t) + c2[i] * t) for i in range(3))
        d.line((x, 0, x, H), fill=c)
    return im

def text(d, xy, s, font, fill, anchor=None):
    d.text(xy, s, font=font, fill=fill, anchor=anchor)

def footer(d, city, subtitle, color):
    text(d, (96, H - 86), city.upper(), SM, color)
    text(d, (W - 96, H - 86), subtitle.upper(), XS, color, anchor="ra")

def chip(d, x=120, y=580, color=(205, 185, 120)):
    w, h = 190, 140
    d.rounded_rectangle((x, y, x + w, y + h), radius=18, fill=color)
    line = (120, 105, 65)
    d.line((x + w * .35, y, x + w * .35, y + h), fill=line, width=4)
    d.line((x + w * .68, y, x + w * .68, y + h), fill=line, width=4)
    d.line((x, y + h * .5, x + w, y + h * .5), fill=line, width=4)
    d.arc((x + w * .18, y + h * .18, x + w * .82, y + h * .82), 0, 360, fill=line, width=4)

def contactless(d, x, y, color):
    for r in (26, 48, 70):
        d.arc((x-r, y-r, x+r, y+r), -48, 48, fill=color, width=7)

def singapore():
    im = gradient((21, 26, 150), (11, 67, 139)); d = ImageDraw.Draw(im)
    for x, c in ((1110,(37,201,114)),(1190,(0,159,144)),(1270,(45,86,200)),(1350,(36,198,224))):
        d.rectangle((x,0,x+46,H), fill=c)
    d.ellipse((100,120,245,265), outline=(64,220,145), width=18)
    d.line((130,195,175,145,225,210), fill=(64,220,145), width=20, joint="curve")
    text(d,(285,125),"CITYLINK",BIG,(245,250,252)); text(d,(100,350),"SINGAPORE",BOLD,(255,255,255))
    text(d,(100,425),"blue / green rapid transit study",SM,(196,230,245)); footer(d,"Singapore","Transit • Classic",(255,255,255))
    return im

def london():
    im = gradient((28,169,224),(17,40,103)); d = ImageDraw.Draw(im)
    d.ellipse((820,-520,1900,1440), outline=(228,232,236), width=92); d.rectangle((1280,0,W,H), fill=(16,47,126))
    d.ellipse((1180,255,1445,520), outline=(245,245,245), width=36); d.rectangle((1135,350,1490,425), fill=(245,245,245))
    text(d,(95,120),"LONDON",BIG,(245,248,252)); text(d,(100,250),"BLUE LINE",BOLD2,(12,54,128))
    text(d,(100,310),"urban transit study · 2003 mood",SM,(245,248,252)); footer(d,"London","Transit • Classic",(245,248,252))
    return im

def hongkong():
    im = gradient((23,30,39),(49,55,67)); d = ImageDraw.Draw(im)
    d.line(((-100,610),(260,350),(610,330),(860,630),(1180,650),(1650,290)), fill=(217,137,78), width=92, joint="curve")
    d.line(((-100,720),(290,470),(580,450),(850,650),(1120,580),(1640,180)), fill=(16,115,226), width=76, joint="curve")
    d.line(((680,340),(920,210),(1160,240),(1480,490)), fill=(16,181,172), width=70, joint="curve")
    text(d,(95,100),"HONG KONG",BOLD,(248,248,248)); text(d,(95,185),"LOOP",BIG,(248,248,248))
    text(d,(95,315),"city motion study",SM,(180,190,202)); footer(d,"Hong Kong","Transit • Loop",(235,238,240)); return im

def tokyo():
    im = gradient((212,215,211),(165,171,170)); d = ImageDraw.Draw(im)
    d.polygon(((0,0),(900,0),(660,H),(0,H)), fill=(54,173,76)); d.polygon(((720,0),(940,0),(705,H),(575,H)), fill=(79,193,93))
    text(d,(1000,110),"TOKYO",BOLD,(35,40,40)); text(d,(1000,190),"RAIL",BIG,(35,40,40)); text(d,(1000,345),"green gate study",SM,(60,66,66))
    d.ellipse((1110,540,1200,655), fill=(25,28,30)); d.ellipse((1128,558,1142,572), fill="white"); d.ellipse((1165,558,1179,572), fill="white")
    d.polygon(((1200,590),(1242,607),(1200,625)), fill=(235,177,65)); d.ellipse((1100,650,1160,690), fill=(25,28,30))
    footer(d,"Tokyo","Transit • Green",(35,40,40)); return im

def seoul():
    im = gradient((12,13,16),(31,32,36)); d = ImageDraw.Draw(im)
    for y in range(160,760,86): d.rounded_rectangle((92,y,1440,y+20), radius=10, fill=(70,72,78))
    text(d,(95,85),"SEOUL",BOLD,(246,246,246)); text(d,(95,166),"T-MOTION",BIG,(246,246,246)); text(d,(95,320),"matte black stripe study",SM,(168,172,180))
    d.rectangle((95,745,650,770), fill=(43,205,188)); d.rectangle((650,745,1080,770), fill=(61,131,246)); footer(d,"Seoul","Transit • Black",(245,245,245)); return im

def paris():
    im = gradient((158,197,226),(120,177,218)); d = ImageDraw.Draw(im); d.rectangle((0,0,350,H), fill=(25,30,38))
    d.rounded_rectangle((66,72,282,288), radius=40, fill=(50,137,212)); d.arc((105,105,243,243),195,345,fill="white",width=18); d.line((170,157,215,203),fill="white",width=18)
    text(d,(430,100),"PARIS",BOLD,(250,250,250)); text(d,(430,182),"NAVIGATION",BIG,(250,250,250)); text(d,(430,335),"Île-de-France blue study",SM,(34,56,74))
    footer(d,"Paris","Transit • Modern",(25,30,38)); return im

def newyork():
    im = gradient((252,195,29),(242,164,23)); d = ImageDraw.Draw(im); d.rectangle((0,650,W,H), fill=(18,20,24))
    d.polygon(((0,500),(780,0),(1120,0),(330,650),(0,650)), fill=(8,94,192)); text(d,(88,95),"METRO",BIG,(250,250,250)); text(d,(88,215),"NEW YORK",BOLD,(20,22,26))
    text(d,(88,300),"yellow / blue swipe-era study",SM,(20,22,26)); text(d,(96,760),"CITY PASS",BOLD,(244,244,244)); footer(d,"New York","Transit • Swipe",(245,245,245)); return im

def sydney():
    im = gradient((20,23,29),(43,45,52)); d = ImageDraw.Draw(im); cx,cy=1180,470
    for i,c in enumerate(((233,76,91),(245,166,35),(44,180,105),(39,151,220),(112,83,204))): d.arc((cx-170,cy-170,cx+170,cy+170),i*72,i*72+72,fill=c,width=70)
    text(d,(95,100),"SYDNEY",BOLD,(246,246,246)); text(d,(95,188),"OPAL NIGHT",BIG,(36,163,220)); text(d,(95,340),"harbour black / spectrum study",SM,(181,187,199))
    footer(d,"Sydney","Transit • Harbour",(246,246,246)); return im

def sg_night():
    im = gradient((10,17,38),(20,63,91)); d = ImageDraw.Draw(im); base=690
    for x,w,h in ((730,110,230),(870,90,330),(980,150,260),(1160,120,390),(1310,100,280)):
        d.rectangle((x,base-h,x+w,base),fill=(24,86,110))
        for yy in range(base-h+30,base-20,50):
            for xx in range(x+20,x+w-10,34): d.rectangle((xx,yy,xx+10,yy+12),fill=(182,231,221))
    d.arc((590,520,1480,950),190,350,fill=(49,204,178),width=18); text(d,(92,95),"LION CITY",BOLD,(242,247,250)); text(d,(92,178),"NIGHT",BIG,(49,204,178))
    chip(d,100,535); contactless(d,400,610,(242,247,250)); text(d,(W-95,95),"VISA",BOLD2,(242,247,250),anchor="ra"); footer(d,"Singapore","Payment • Visa-style",(242,247,250)); return im

def sg_jade():
    im = gradient((17,110,95),(25,40,63)); d = ImageDraw.Draw(im)
    for i in range(6):
        y=180+i*70; d.arc((520,y,1540,y+440),180,355,fill=(120+12*i,220,190),width=18)
    text(d,(95,90),"MARINA",BOLD,(248,248,245)); text(d,(95,173),"JADE",BIG,(219,244,225)); text(d,(95,322),"Singapore payment study",SM,(205,230,222))
    chip(d,100,535); text(d,(W-95,95),"VISA",BOLD2,(248,248,245),anchor="ra"); footer(d,"Singapore","Payment • Visa-style",(248,248,245)); return im

def uk_navy():
    im = gradient((10,32,76),(28,52,92)); d = ImageDraw.Draw(im)
    d.polygon(((0,0),(190,0),(W,H-140),(W,H),(W-180,H)),fill=(175,32,54)); d.polygon(((W,0),(W-200,0),(0,H-120),(0,H),(180,H)),fill=(239,239,232)); d.polygon(((W,0),(W-120,0),(0,H-250),(0,H-160)),fill=(175,32,54))
    text(d,(95,95),"BRITANNIA",BOLD,(250,250,248)); text(d,(95,178),"NAVY",BIG,(250,250,248)); chip(d,100,535); text(d,(W-95,95),"VISA",BOLD2,(250,250,248),anchor="ra")
    footer(d,"United Kingdom","Payment • Visa-style",(250,250,248)); return im

def uk_fog():
    im = gradient((132,145,156),(55,67,82)); d = ImageDraw.Draw(im); d.rectangle((780,510,1460,555),fill=(34,40,48)); d.rectangle((860,360,950,700),fill=(34,40,48)); d.rectangle((1270,360,1360,700),fill=(34,40,48)); d.arc((820,380,1400,700),180,360,fill=(34,40,48),width=24)
    for y in (200,300,415): d.rounded_rectangle((520,y,1510,y+52),radius=26,fill=(184,194,202))
    text(d,(95,95),"LONDON",BOLD,(247,248,248)); text(d,(95,178),"FOG",BIG,(247,248,248)); chip(d,100,535); text(d,(W-95,95),"VISA",BOLD2,(247,248,248),anchor="ra")
    footer(d,"United Kingdom","Payment • Visa-style",(247,248,248)); return im

CARDS = [
    ("transit/singapore/singapore-link-classic.png", singapore, "Singapore Link Classic", "transit", "Singapore", "EZ-Link-era blue/green stripe language"),
    ("transit/uk/london-blue-line.png", london, "London Blue Line", "transit", "United Kingdom", "Oyster-era blue/white/navy language"),
    ("transit/hong-kong/hk-loop.png", hongkong, "Hong Kong Loop", "transit", "Hong Kong", "Octopus-style dark field with looping ribbon"),
    ("transit/japan/tokyo-green-rail.png", tokyo, "Tokyo Green Rail", "transit", "Japan", "Suica-era silver/green language"),
    ("transit/korea/seoul-black-stripe.png", seoul, "Seoul Black Stripe", "transit", "South Korea", "T-money matte black stripe language"),
    ("transit/france/paris-navigation-blue.png", paris, "Paris Navigation Blue", "transit", "France", "Navigo blue/black language"),
    ("transit/usa/new-york-swipe-yellow.png", newyork, "New York Swipe Yellow", "transit", "United States", "MetroCard yellow/blue swipe-era language"),
    ("transit/australia/sydney-opal-night.png", sydney, "Sydney Opal Night", "transit", "Australia", "Opal charcoal + spectrum language"),
    ("payment/singapore/lion-city-night-visa.png", sg_night, "Lion City Night", "payment", "Singapore", "Visa-style city night concept"),
    ("payment/singapore/marina-jade-visa.png", sg_jade, "Marina Jade", "payment", "Singapore", "Visa-style jade / marina concept"),
    ("payment/uk/britannia-navy-visa.png", uk_navy, "Britannia Navy", "payment", "United Kingdom", "Visa-style navy British geometry"),
    ("payment/uk/london-fog-visa.png", uk_fog, "London Fog", "payment", "United Kingdom", "Visa-style fog / bridge concept"),
]

def main():
    entries=[]
    for rel, fn, name, category, region, inspiration in CARDS:
        path=ROOT/rel; path.parent.mkdir(parents=True, exist_ok=True); fn().save(path,"PNG",optimize=True)
        entries.append({"id":rel[:-4].replace("/","-"),"name":name,"category":category,"region":region,"file":rel,"size":[W,H],"format":"png","inspired_by":inspiration,"original_artwork":True,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest={"schema_version":1,"library":"AirCard Community Skin Library","canvas":{"width":W,"height":H,"aspect_ratio":round(W/H,6),"format":"PNG"},"license_note":"Original artwork created for this fork. Third-party names and trademarks referenced only to describe design inspiration; no affiliation or endorsement is implied.","cards":entries}
    (ROOT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    tw=420; th=round(tw*H/W); cols=3; rows=math.ceil(len(CARDS)/cols); label=pick_font(FONT_CANDIDATES,24)
    sheet=Image.new("RGB",(cols*tw,(th+70)*rows),(28,28,30)); sd=ImageDraw.Draw(sheet)
    for i,e in enumerate(entries):
        im=Image.open(ROOT/e["file"]).convert("RGB"); im.thumbnail((tw,th)); x=(i%cols)*tw; y=(i//cols)*(th+70); sheet.paste(im,(x,y)); sd.text((x+12,y+th+10),e["name"],font=label,fill=(245,245,245))
    sheet.save(ROOT/"PREVIEW.jpg","JPEG",quality=88,optimize=True)
    print(f"Generated {len(entries)} skins in {ROOT}")

if __name__ == "__main__":
    main()
