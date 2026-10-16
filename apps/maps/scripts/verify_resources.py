#!/usr/bin/env python3
"""Verify bilingual resources, API permission strings, and app artwork."""
from pathlib import Path
import json
import re
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / 'MapsSix'
resources = {}
for language in ('en', 'zh-Hans'):
    folder = ROOT / f'{language}.lproj'
    resources[language] = dict(re.findall(r'^"((?:\\.|[^"\\])*)" = "((?:\\.|[^"\\])*)";', (folder / 'Localizable.strings').read_text(), re.M))
    info = (folder / 'InfoPlist.strings').read_text()
    assert 'CFBundleDisplayName' in info and 'NSLocationWhenInUseUsageDescription' in info
assert resources['en'].keys() == resources['zh-Hans'].keys()
for key, value in resources['zh-Hans'].items():
    assert value and key.count('%') == value.count('%'), key
for path in ROOT.rglob('*.swift'):
    for key in re.findall(r'L10n\.(?:text|format)\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"', path.read_text()):
        assert key in resources['en'], (path, key)
for path in ROOT.rglob('Contents.json'):
    manifest = json.loads(path.read_text())
    for item in manifest.get('images', []):
        if 'filename' in item:
            image_path = path.parent / item['filename']
            assert image_path.is_file(), image_path
            with Image.open(image_path) as image:
                image.verify()
icon_path = ROOT / 'Assets.xcassets/AppIcon.appiconset/maps-icon.png'
with Image.open(icon_path) as image:
    assert image.size == (1024, 1024) and image.mode == 'RGB'
print(f'Validated {len(resources["en"])} bilingual keys, permission strings, artwork, and localization lookups')
