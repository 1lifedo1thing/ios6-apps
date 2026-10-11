#!/usr/bin/env python3
"""Package committed original artwork into the app's asset catalog."""

from pathlib import Path
import json
import shutil
from PIL import Image

APP_ROOT = Path(__file__).resolve().parent.parent
ROOT = APP_ROOT / "CompassSix/Assets.xcassets"
ROOT.mkdir(parents=True, exist_ok=True)
(ROOT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}))

walnut = ROOT / "Walnut.imageset"
walnut.mkdir(exist_ok=True)
shutil.copyfile(APP_ROOT / "artwork/walnut-source.png", walnut / "walnut.png")
(walnut / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "walnut.png", "idiom": "universal"}],
    "info": {"author": "xcode", "version": 1},
}, indent=2))

appicon = ROOT / "AppIcon.appiconset"
appicon.mkdir(exist_ok=True)
with Image.open(APP_ROOT / "artwork/compass-icon-source.png") as source:
    if source.width != source.height:
        raise ValueError("The authored app icon must be square.")
    icon = source.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    icon.save(appicon / "compass-icon.png", optimize=True)
(appicon / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "compass-icon.png", "idiom": "universal",
                "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1},
}, indent=2))
print("Packaged original walnut and app icon artwork")
