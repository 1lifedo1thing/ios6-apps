#!/usr/bin/env python3
"""Draw original cartographic icon, dimensional pushpin, and linen texture."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import random, json, math
ROOT=Path(__file__).resolve().parent.parent/'MapsSix'/'Assets.xcassets'
ROOT.mkdir(exist_ok=True)
(ROOT/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
def asset(name,image,scale='1x'):
    folder=ROOT/f'{name}.imageset';folder.mkdir(exist_ok=True);image.save(folder/f'{name}.png')
    (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':f'{name}.png','idiom':'universal','scale':scale}],'info':{'author':'xcode','version':1}},indent=2))
rng=random.Random(612)
linen=Image.new('RGB',(128,128));pix=linen.load()
for y in range(128):
 for x in range(128):
  v=round(68+(x%3==0)*5-(y%3==0)*7+rng.uniform(-3,3));pix[x,y]=(v,v+1,v+1)
asset('MapLinen',linen)
S=4
pin=Image.new('RGBA',(46*S,60*S));d=ImageDraw.Draw(pin)
d.ellipse((12*S,47*S,44*S,55*S),fill=(0,0,0,45))
d.polygon([(20*S,17*S),(25*S,19*S),(17*S,52*S)],fill=(55,57,60,255))
d.line((23*S,22*S,17*S,51*S),fill=(239,240,241),width=2*S)
for r in range(10*S,0,-1):
 t=1-r/(10*S);cx=22*S;cy=16*S
 d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=(int(140+80*t),int(12+25*t),int(14+25*t),255))
d.ellipse((16*S,9*S,23*S,14*S),fill=(255,206,189,230))
asset('RedPin',pin.resize((92,120),Image.Resampling.LANCZOS),'2x')
w=1024;icon=Image.new('RGB',(w,w));d=ImageDraw.Draw(icon)
for y in range(w):
 t=y/w;d.line((0,y,w,y),fill=(int(225-23*t),int(231-20*t),int(216-22*t)))
d.polygon([(0,75),(270,0),(430,0),(0,480)],fill=(163,195,147))
d.polygon([(745,0),(1024,0),(1024,1024),(900,1024),(765,730),(827,410)],fill=(130,183,208))
for pts,width in [([(0,240),(1024,430)],65), ([(0,690),(1024,780)],76), ([(230,0),(365,1024)],65), ([(620,0),(740,1024)],70)]:
 d.line(pts,fill=(175,180,174),width=width+10);d.line(pts,fill=(254,253,242),width=width)
pts=[(-50,1030),(150,760),(310,580),(560,330),(735,0)]
d.line(pts,fill=(168,142,78),width=143,joint='curve');d.line(pts,fill=(255,220,105),width=125,joint='curve');d.line(pts,fill=(255,243,179),width=34,joint='curve')
shield=[(725,92),(779,117),(837,92),(900,116),(893,210),(865,253),(808,282),(751,250),(729,210)]
d.polygon(shield,fill=(240,240,232),outline=(255,255,255),width=9)
d.polygon([(740,120),(780,137),(837,114),(885,131),(881,171),(742,171)],fill=(173,42,39))
d.polygon([(742,179),(882,179),(876,210),(852,238),(808,260),(766,236),(747,208)],fill=(30,75,124))
fontpath='/System/Library/Fonts/Helvetica.ttc'
try: font=ImageFont.truetype(fontpath,63)
except OSError: font=ImageFont.load_default()
d.text((756,177),'280',font=font,fill='white')
shadow=Image.new('RGBA',icon.size);sd=ImageDraw.Draw(shadow)
arrow=[(556,299),(757,829),(557,733),(352,831)]
sd.polygon([(x+4,y+18) for x,y in arrow],fill=(0,0,0,140));shadow=shadow.filter(ImageFilter.GaussianBlur(13));icon=Image.alpha_composite(icon.convert('RGBA'),shadow);d=ImageDraw.Draw(icon)
d.polygon(arrow,fill=(18,68,126),outline=(240,249,255),width=13)
d.polygon([(556,323),(556,710),(374,800)],fill=(68,159,238))
d.polygon([(563,323),(734,799),(563,710)],fill=(26,105,193))
d.line([(556,338),(556,704)],fill=(165,222,255),width=5)
# Restrained top light and lower bevel; the device supplies the outer mask.
d.line((0,3,1024,3),fill=(255,255,255,255),width=5)
folder=ROOT/'AppIcon.appiconset';folder.mkdir(exist_ok=True)
icon.convert('RGB').save(folder/'maps-icon.png')
(folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'maps-icon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
print('Generated original icon, pin and linen')
