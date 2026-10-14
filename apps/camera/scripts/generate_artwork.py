#!/usr/bin/env python3
"""Draw simulator scenes and texture; export the refined opaque camera icon master."""
from pathlib import Path
import json
import random
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent / "CameraSix" / "Assets.xcassets"
random.seed(6)

def save_asset(name, image):
    folder = ROOT / (name + ".imageset")
    folder.mkdir(parents=True, exist_ok=True)
    image.save(folder / (name + ".jpg"), quality=95)
    (folder / "Contents.json").write_text(json.dumps({"images": [{"filename": name + ".jpg", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

def scene(width, height, front=False):
    image = Image.new("RGB", (width, height))
    d = ImageDraw.Draw(image)
    for y in range(height):
        t = y / height
        if t < .52:
            p = t / .52
            color = (int(68 + 126*p), int(150 + 65*p), int(196 + 33*p))
        else:
            p = (t - .52) / .48
            color = (int(70 - 40*p), int(127 - 65*p), int(133 - 58*p))
        d.line((0, y, width, y), fill=color)
    clouds = Image.new("RGBA", (width, height))
    cd = ImageDraw.Draw(clouds)
    for _ in range(16):
        x = random.randint(0, width); y = random.randint(int(height*.03), int(height*.29))
        for j in range(4):
            r = random.randint(int(height*.02), int(height*.05))
            cd.ellipse((x+j*r-r, y-r//2, x+j*r+r, y+r//2), fill=(255, 250, 235, 120))
    image = Image.alpha_composite(image.convert("RGBA"), clouds.filter(ImageFilter.GaussianBlur(height*.012))).convert("RGB")
    d = ImageDraw.Draw(image)
    for level, color in [(0, (128, 159, 164)), (1, (87, 132, 136)), (2, (47, 100, 104))]:
        pts = [(0, int(height*.54))]
        for x in range(0, width+100, max(50,width//9)):
            pts.append((x, int(height*(.44 + .05*level)) - random.randint(0, int(height*.15))))
        pts.extend([(width, int(height*.58)), (0,int(height*.58))])
        d.polygon(pts, fill=color)
    for _ in range(1400):
        y = random.randint(int(height*.54), int(height*.98)); x = random.randint(0,width)
        a = (y/height-.5)*2
        d.line((x,y,x+random.randint(4,30),y), fill=(int(110-55*a),int(163-70*a),int(167-65*a)),width=1)
    # A quiet lakeside cabin and warm timber pier provide detailed focus/registration targets.
    cx = int(width*(.64 if not front else .37)); cy = int(height*.53)
    cw=int(height*.22); ch=int(height*.13)
    d.rectangle((cx-cw//2,cy-ch,cx+cw//2,cy),fill=(173,121,72))
    for y in range(cy-ch,cy,7): d.line((cx-cw//2,y,cx+cw//2,y),fill=(133,88,53),width=2)
    d.polygon([(cx-cw*.63,cy-ch),(cx,cy-ch*1.6),(cx+cw*.63,cy-ch)],fill=(74,65,54))
    for x in [cx-cw*.31,cx+cw*.20]:
        d.rectangle((x,cy-ch*.75,x+cw*.16,cy-ch*.30),fill=(219,216,172),outline=(62,64,52),width=3)
    d.polygon([(int(width*.45),height),(int(width*.81),height),(int(width*.69),int(height*.61)),(int(width*.60),int(height*.61))],fill=(171,134,96))
    for i in range(22):
        y=int(height*.61+(height*.39)*(i/22)**1.5)
        left=width*(.60-.15*(i/22)**1.5);right=width*(.69+.12*(i/22)**1.5)
        d.line((left,y,right,y),fill=(99,75,54),width=max(1,int(i/5)))
    for side in [.44,.83]:
        x=int(width*side)
        d.rectangle((x,int(height*.79),x+int(height*.018),height),fill=(88,64,44))
        d.ellipse((x-2,int(height*.79)-3,x+int(height*.018)+2,int(height*.79)+6),fill=(167,134,94))
    # Original illustrated foliage, with consistent fine grain.
    for side in [0,width]:
        for i in range(30):
            y=random.randint(int(height*.15),int(height*.78)); span=random.randint(int(height*.03),int(height*.17))
            x=side + (span*.25 if side==0 else -span*.25)
            d.line((side,y,x+(-span if side else span),y-int(span*.4)),fill=(39,63,34),width=5)
            for j in range(12):
                px=x+(-1 if side else 1)*j*span/15; py=y-j*span/35
                d.ellipse((px-span*.12,py-span*.08,px+span*.12,py+span*.08),fill=random.choice([(51,91,48),(64,110,54),(86,126,58),(108,141,66)]))
    return image

ROOT.mkdir(parents=True,exist_ok=True)
(ROOT/"Contents.json").write_text('{"info":{"author":"xcode","version":1}}\n')
save_asset("DemoScene",scene(960,1280))
save_asset("DemoFront",scene(960,1280,True))
save_asset("DemoPanorama",scene(2400,960))

size=1024
master = Path(__file__).resolve().parent.parent / "artwork/CameraIcon-master.png"
with Image.open(master) as image:
    assert image.width == image.height, "Camera icon master must be square"
    icon = image.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
folder=ROOT/"AppIcon.appiconset";folder.mkdir(exist_ok=True)
icon.save(folder/"AppIcon.png")
(folder/"Contents.json").write_text(json.dumps({"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}},indent=2)+'\n')
# Neutral micro-grain for the graphite iris, generated once rather than per animation frame.
grain_rng = random.Random(0x1A15)
grain = Image.new("RGBA", (768, 1024))
grain.putdata([
    ((255, 255, 255, grain_rng.randrange(1, 5)) if grain_rng.random() > .5
     else (0, 0, 0, grain_rng.randrange(1, 7)))
    for _ in range(grain.width * grain.height)
])
folder = ROOT / "IrisGrain.imageset"
folder.mkdir(exist_ok=True)
grain.save(folder / "IrisGrain.png")
(folder / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "IrisGrain.png", "idiom": "universal"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2) + "\n")
print("Generated CameraSix scenes/texture and exported refined icon")
