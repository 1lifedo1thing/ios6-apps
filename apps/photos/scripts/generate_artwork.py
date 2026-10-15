#!/usr/bin/env python3
"""Draw original landscape fixtures and a dimensional sunflower icon."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math, random, json
ROOT = Path(__file__).resolve().parent.parent / 'PhotosSix'
DEMO = ROOT / 'Demo.bundle'
DEMO.mkdir(exist_ok=True)

def landscape(index):
    rng = random.Random(610 + index)
    w,h=1200,900
    im=Image.new('RGB',(w,h));d=ImageDraw.Draw(im)
    palettes=[((43,132,184),(217,227,209),(32,103,123)),((62,108,146),(249,204,161),(60,111,118)),((139,154,164),(234,223,192),(67,100,99)),((42,94,128),(189,213,210),(30,86,105))]
    top,low,water=palettes[index%4]
    for y in range(h):
        t=min(1,y/(h*.58));color=tuple(int(top[c]*(1-t)+low[c]*t) for c in range(3)) if y<h*.58 else water
        d.line((0,y,w,y),fill=color)
    clouds=Image.new('RGBA',im.size);cd=ImageDraw.Draw(clouds)
    for _ in range(15):
        x=rng.randrange(w);y=rng.randrange(50,280);r=rng.randrange(20,60)
        for j in range(5):cd.ellipse((x+j*r-r,y-r*.4,x+j*r+r,y+r*.4),fill=(255,250,240,110))
    im=Image.alpha_composite(im.convert('RGBA'),clouds.filter(ImageFilter.GaussianBlur(16))).convert('RGB');d=ImageDraw.Draw(im)
    if index%4==1: d.ellipse((855,122,957,224),fill=(255,233,179))
    for level,color in [(0,(132,163,165)),(1,(82,133,141)),(2,(39,99,110))]:
        pts=[(-80,h*.62)]
        for x in range(-80,w+160,130):pts.append((x,h*(.50+level*.04)-rng.randrange(10,190)))
        pts.extend([(w+100,h*.65),(-100,h*.65)])
        d.polygon(pts,fill=color)
        if index%3==0 and level==0:
            for j in range(2,len(pts)-3):
                x,y=pts[j];d.polygon([(x-33,y+38),(x,y),(x+24,y+37),(x+4,y+23),(x-8,y+35)],fill=(226,234,227))
    for _ in range(2300):
        x=rng.randrange(w);y=rng.randrange(int(h*.62),h);a=(y/h-.6)*2
        d.line((x,y,x+rng.randrange(2,40),y),fill=(int(100-a*45),int(158-a*55),int(165-a*40)))
    if index%3==0:
        # Sailboat with reflected mast.
        x=650+index*10;y=640
        d.polygon([(x-85,y),(x+64,y),(x+43,y+23),(x-62,y+23)],fill=(70,58,44))
        d.line((x,y,x,y-230),fill=(78,66,51),width=4)
        d.polygon([(x-7,y-220),(x-7,y-10),(x-132,y-10)],fill=(249,240,214))
        d.polygon([(x+5,y-185),(x+5,y-10),(x+95,y-10)],fill=(229,221,197))
    elif index%3==1:
        # Lake cabin and meadow.
        x=820;y=555;d.rectangle((x-90,y-98,x+90,y),fill=(173,120,71));d.polygon([(x-110,y-98),(x,y-174),(x+110,y-98)],fill=(69,63,57))
        for xx in [x-60,x+25]:d.rectangle((xx,y-73,xx+35,y-25),fill=(239,215,146),outline=(68,64,45),width=4)
        d.polygon([(0,820),(400,750),(820,620),(1200,610),(1200,900),(0,900)],fill=(87,119,55))
    else:
        # White coastal lighthouse.
        x=830;y=540;d.polygon([(x-40,y),(x-26,y-192),(x+26,y-192),(x+44,y)],fill=(232,223,194))
        d.rectangle((x-35,y-217,x+35,y-185),fill=(72,71,62));d.polygon([(x-43,y-217),(x,y-250),(x+43,y-217)],fill=(109,60,48))
        d.polygon([(590,790),(840,535),(1200,665),(1200,900),(600,900)],fill=(97,107,72))
    # Foreground branches, grass and field flowers.
    for _ in range(220):
        x=rng.randrange(w);y=rng.randrange(800,960);r=rng.randrange(4,15)
        d.line((x,y,x+rng.randrange(-22,22),y-r*5),fill=rng.choice([(39,77,46),(56,96,44),(93,121,53)]),width=3)
        if index%2==0:d.ellipse((x-r,y-r*5-r,x+r,y-r*5+r),fill=rng.choice([(225,197,83),(231,227,196),(168,159,192)]))
    return im.filter(ImageFilter.GaussianBlur(.3))

for i in range(12): landscape(i).save(DEMO/f'Scene{i}.jpg',quality=92)

# Export the reviewed photographic icon master; iOS supplies the outer mask.
master = ROOT.parent / 'artwork' / 'PhotosIcon-master.png'
with Image.open(master) as source:
    icon=source.convert('RGB').resize((1024,1024),Image.Resampling.LANCZOS)
asset=ROOT/'Assets.xcassets'/'AppIcon.appiconset';asset.mkdir(parents=True,exist_ok=True)
icon.save(asset/'AppIcon.png')
(asset/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
(ROOT/'Assets.xcassets'/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
print('Generated 12 original scenes and exported photographic sunflower icon')
