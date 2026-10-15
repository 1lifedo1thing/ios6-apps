#!/usr/bin/env python3
"""Check localization coverage, privacy aliases, icon format, and project registration."""
from pathlib import Path
from PIL import Image
import json, plistlib, re, subprocess
ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'PhotosSix'
def strings(path):
    result={}
    for line in path.read_text().splitlines():
        match=re.fullmatch(r'("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");',line)
        assert match, (path,line)
        key,value=map(json.loads,match.groups());assert key not in result,(path,key)
        result[key]=value
    return result
en=strings(SOURCE/'en.lproj/Localizable.strings');zh=strings(SOURCE/'zh-Hans.lproj/Localizable.strings')
assert en.keys()==zh.keys()
required=set()
for path in SOURCE.rglob('*.swift'):
    required.update(re.findall(r'L10n\.(?:text|format)\(\s*"([^"\\]+)"',path.read_text()))
assert not required-en.keys(),required-en.keys()
for language in ['en','zh-Hans','zh-Hant','zh']:
    values=strings(SOURCE/f'{language}.lproj/InfoPlist.strings')
    assert set(values)=={'CFBundleDisplayName','NSPhotoLibraryUsageDescription','NSPhotoLibraryAddUsageDescription'}
    if language!='en': assert values['CFBundleDisplayName']=='照片'
info=plistlib.loads((SOURCE/'Info.plist').read_bytes())
assert info['CFBundleURLTypes'][0]['CFBundleURLSchemes']==['photossix']
assert info['LSApplicationQueriesSchemes']==['camerasix']
with Image.open(SOURCE/'Assets.xcassets/AppIcon.appiconset/AppIcon.png') as image:
    assert image.size==(1024,1024) and image.mode=='RGB'
assert len(list((SOURCE/'Demo.bundle').glob('Scene*.jpg')))==12
assert (SOURCE/'Demo.bundle/DemoVideo.mov').stat().st_size>1000
workspace=ROOT.parent.parent/'iOS6Apps.xcworkspace/contents.xcworkspacedata'
assert 'group:apps/photos/PhotosSix.xcodeproj' in workspace.read_text()
for path in [SOURCE/'Info.plist',ROOT/'PhotosSix.xcodeproj/project.pbxproj']:
    subprocess.run(['plutil','-lint',str(path)],check=True,capture_output=True)
print(f'Passed: {len(en)} paired strings, permissions, URL schemes, icon, demo media, and workspace')
