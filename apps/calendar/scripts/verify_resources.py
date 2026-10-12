#!/usr/bin/env python3
"""Validate localization coverage, placeholders, asset metadata, and registration."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'CalendarSix'

def plist(path):
    return json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))

strings = {lang: plist(APP / f'{lang}.lproj/Localizable.strings') for lang in ['en', 'zh-Hans']}
assert strings['en'].keys() == strings['zh-Hans'].keys(), 'Localization key mismatch'
for key in strings['en']:
    assert all(strings[lang][key] for lang in strings), key
    placeholders = lambda value: re.findall(r'%[\d.]*[diu@fs]', value)
    assert placeholders(strings['en'][key]) == placeholders(strings['zh-Hans'][key]), key
source = '\n'.join(path.read_text() for path in APP.rglob('*.swift'))
keys = set(re.findall(r'L10n\.(?:text|format)\("([^"\\]+)"', source))
assert not keys - strings['en'].keys(), keys - strings['en'].keys()
for lang in strings:
    info = plist(APP / f'{lang}.lproj/InfoPlist.strings')
    assert info['CFBundleDisplayName'] and info['NSCalendarsFullAccessUsageDescription']
for contents in (APP / 'Assets.xcassets').rglob('Contents.json'):
    data = json.loads(contents.read_text())
    for image in data.get('images', []):
        if 'filename' in image:
            assert (contents.parent / image['filename']).is_file()
workspace = ROOT.parent.parent / 'iOS6Apps.xcworkspace/contents.xcworkspacedata'
assert 'group:apps/calendar/CalendarSix.xcodeproj' in workspace.read_text()
icons = json.loads((ROOT / 'scripts/alternate_icons.json').read_text())
expected = {f'CalendarDate_{lang}_w{weekday}_d{day}' for lang in ['en', 'zh-Hans'] for weekday in range(1, 8) for day in range(1, 32)}
assert len(icons) == len(set(icons)) and set(icons) == expected, 'Date icon matrix mismatch'
for name in icons:
    assert (APP / 'Assets.xcassets' / f'{name}.appiconset' / 'Icon.png').is_file(), name
project = plist(ROOT / 'CalendarSix.xcodeproj/project.pbxproj')
app_configs = [obj['buildSettings'] for obj in project['objects'].values() if obj.get('isa') == 'XCBuildConfiguration' and obj.get('buildSettings', {}).get('PRODUCT_BUNDLE_IDENTIFIER') == 'com.yinyueyang.calendarsix']
assert len(app_configs) == 2
assert all(set(config['ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES']) == expected for config in app_configs)
print(f'PASS: {len(strings["en"])} bilingual keys, placeholders, lookup coverage, permissions, assets, workspace, {len(icons)} registered date icons')
