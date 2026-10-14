#!/usr/bin/env python3
"""Validate localization parity, placeholders, privacy prompts, assets, and workspace registration."""
from pathlib import Path
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "CameraSix"

def strings(path):
    result = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)],
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)

english = strings(SOURCE / "en.lproj/Localizable.strings")
chinese = strings(SOURCE / "zh-Hans.lproj/Localizable.strings")
assert english.keys() == chinese.keys(), "Mismatched localization keys"
for key in english:
    assert re.findall(r"%[\d$]*[d@f]", english[key]) == re.findall(r"%[\d$]*[d@f]", chinese[key]), key
    assert english[key] and chinese[key], key
for file in SOURCE.rglob("*.swift"):
    for key in re.findall(r'L10n\.(?:text|format)\("([^"\\]+)"', file.read_text()):
        assert key in english, f"Missing key {key} in {file}"

privacy_keys = {"CFBundleDisplayName", "NSCameraUsageDescription", "NSMicrophoneUsageDescription",
                "NSPhotoLibraryAddUsageDescription", "NSPhotoLibraryUsageDescription"}
for language in ["en", "zh-Hans", "zh-Hant", "zh"]:
    assert strings(SOURCE / f"{language}.lproj/InfoPlist.strings").keys() == privacy_keys
assert strings(SOURCE / "zh-Hant.lproj/InfoPlist.strings") == strings(SOURCE / "zh-Hans.lproj/InfoPlist.strings")

assets = SOURCE / "Assets.xcassets"
for contents in assets.rglob("Contents.json"):
    for item in json.loads(contents.read_text()).get("images", []):
        if "filename" in item:
            image = contents.parent / item["filename"]
            with Image.open(image) as bitmap:
                bitmap.verify()
with Image.open(assets / "AppIcon.appiconset/AppIcon.png") as icon:
    assert icon.size == (1024, 1024) and icon.mode == "RGB"

workspace = ROOT.parents[1] / "iOS6Apps.xcworkspace/contents.xcworkspacedata"
assert "group:apps/camera/CameraSix.xcodeproj" in [item.attrib["location"] for item in ET.parse(workspace).getroot()]
ET.parse(ROOT / "CameraSix.xcodeproj/xcshareddata/xcschemes/CameraSix.xcscheme")
print(f"PASS: {len(english)} bilingual strings, Chinese privacy aliases, assets, shared scheme and workspace")
