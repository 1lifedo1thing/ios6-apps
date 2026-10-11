#!/usr/bin/env python3
"""Generate original clock icon artwork, synthesized chimes, and bilingual resources."""
from pathlib import Path
import json
import math
import struct
import wave
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'ClockSix'
TRANSLATIONS = {
    'Songs': '歌曲', 'Song': '歌曲', 'Pick a song': '选取歌曲', 'Music Library': '音乐资料库',
    'Music selection requires a physical iPhone with downloaded songs.': '选取音乐需要使用已下载歌曲的真实 iPhone。',
    'Music access is unavailable. You can still use the built-in tones.': '无法访问音乐资料库，你仍可使用内置声音。',
    'Songs play while Clock is open. Background reminders use the selected built-in tone.': '时钟保持打开时会播放歌曲。后台提醒使用所选的内置声音。',
    'Clock uses your downloaded songs as foreground alarm sounds.': '时钟使用你下载的歌曲作为前台闹钟声音。',
    'Clock': '时钟', 'World Clock': '世界时钟', 'Alarm': '闹钟', 'Stopwatch': '秒表', 'Timer': '计时器',
    'Edit': '编辑', 'Done': '完成', 'Cancel': '取消', 'Save': '存储', 'Back': '返回', 'Add': '添加',
    'Start': '开始', 'Stop': '停止', 'Pause': '暂停', 'Resume': '继续', 'Lap': '分圈', 'Reset': '复位',
    'Repeat': '重复', 'Sound': '声音', 'Snooze': '稍后提醒', 'Label': '标签', 'Never': '永不',
    'Every day': '每天', 'Weekdays': '工作日', 'Weekends': '周末', 'Today': '今天', 'Yesterday': '昨天',
    'Tomorrow': '明天', 'ON': '开', 'OFF': '关', 'Search': '搜索', 'Clear search': '清除搜索',
    'No cities found': '未找到城市', 'No World Clocks': '没有世界时钟', 'No Alarms': '没有闹钟',
    'Choose a City': '选择城市', 'Add Alarm': '添加闹钟', 'Edit Alarm': '编辑闹钟', 'Delete': '删除',
    'Move up': '上移', 'Move down': '下移', 'Hours': '小时', 'Minutes': '分钟', 'hours': '小时', 'min': '分',
    'AM': '上午', 'PM': '下午', 'When Timer Ends': '计时结束时启用', 'Timer finished': '计时结束',
    'Elapsed time': '已用时间', 'Current lap': '本圈用时', 'Time remaining': '剩余时间',
    'Marimba': '马林巴琴', 'Bell Tower': '钟楼', 'Digital': '数码', 'Ascending': '渐强', 'None': '无',
    'Stop Playing': '停止播放', 'OK': '好',
    "Couldn't save clock data. Please try again.": '无法存储时钟数据，请重试。',
    "Couldn't schedule the reminder. Please try again.": '无法安排提醒，请重试。',
    'Too many repeating alarms. Reduce the number of repeat days or alarms.': '重复闹钟过多，请减少重复天数或闹钟数量。',
    'Enable notifications in Settings for background reminders.': '请在设置中允许通知，以接收后台提醒。',
    'Stop Playing pauses other audio while Clock is open. In the background, the timer delivers a silent notification.': '时钟保持打开时，“停止播放”会暂停其他音频。在后台，计时器会发送静音通知。',
}
for language in ['en', 'zh-Hans']:
    folder = APP / f'{language}.lproj'
    folder.mkdir(parents=True, exist_ok=True)
    lines = [f'{json.dumps(key, ensure_ascii=False)} = {json.dumps(value if language == "zh-Hans" else key, ensure_ascii=False)};' for key, value in TRANSLATIONS.items()]
    (folder / 'Localizable.strings').write_text('\n'.join(lines) + '\n')
    (folder / 'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "{"时钟" if language == "zh-Hans" else "Clock"}";\n' + '"NSAppleMusicUsageDescription" = ' + json.dumps(TRANSLATIONS['Clock uses your downloaded songs as foreground alarm sounds.'] if language == 'zh-Hans' else 'Clock uses your downloaded songs as foreground alarm sounds.', ensure_ascii=False) + ';\n')

side = 1024
icon = Image.new('RGB', (side, side))
pixels = icon.load()
for y in range(side):
    for x in range(side):
        glow = max(0, 1 - math.hypot(x - 360, y - 180) / 1000)
        shade = int(12 + 38 * glow + (9 if y < 512 else 0))
        pixels[x, y] = (shade, shade + 1, shade + 3)
draw = ImageDraw.Draw(icon)
for inset in range(30):
    gray = int(80 + 130 * inset / 30)
    draw.ellipse((110 + inset, 110 + inset, 914 - inset, 914 - inset), fill=(gray, gray, gray))
draw.ellipse((144, 144, 880, 880), fill=(247, 247, 239))
for tick in range(60):
    a = tick * math.pi / 30
    outer = 336
    inner = 305 if tick % 5 == 0 else 323
    start = (512 + math.sin(a) * inner, 512 - math.cos(a) * inner)
    end = (512 + math.sin(a) * outer, 512 - math.cos(a) * outer)
    draw.line((start, end), fill=(34, 34, 33), width=10 if tick % 5 == 0 else 4)
def hand(angle, length, width, color, tail=35):
    a = angle * math.pi / 180
    draw.line((512 - math.sin(a)*tail, 512 + math.cos(a)*tail, 512 + math.sin(a)*length, 512 - math.cos(a)*length), fill=color, width=width)
hand(305, 203, 30, (30, 30, 30))
hand(60, 288, 20, (30, 30, 30))
hand(180, 306, 6, (192, 26, 32), 75)
draw.ellipse((496, 496, 528, 528), fill=(191, 31, 33))
draw.ellipse((507, 507, 517, 517), fill=(231, 214, 201))
icon_dir = APP / 'Assets.xcassets/AppIcon.appiconset'
icon_dir.mkdir(parents=True, exist_ok=True)
icon.save(icon_dir / 'AppIcon.png', optimize=True)
(icon_dir / 'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}], 'info':{'author':'xcode','version':1}}) + '\n')
(APP/'Assets.xcassets/Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')

# Original synthesized sound patterns; no Apple audio assets are copied.
patterns = {'marimba':[523.25,659.25,783.99,659.25,523.25,783.99], 'bell':[523.25,392,440,349.23], 'digital':[880,880,1174.66,1174.66], 'ascending':[392,440,493.88,523.25,587.33,659.25,783.99,880]}
for name, notes in patterns.items():
    rate = 22050
    duration = 3.6
    frames = []
    step = duration / len(notes)
    for index in range(int(rate*duration)):
        time = index / rate
        note_index = min(int(time/step), len(notes)-1)
        local = time - note_index*step
        freq = notes[note_index]
        envelope = min(1, local*180) * math.exp(-local*(5 if name == 'bell' else 9))
        signal = math.sin(2*math.pi*freq*local) + 0.24*math.sin(2*math.pi*freq*2.01*local)
        frames.append(struct.pack('<h', int(11000 * envelope * signal)))
    with wave.open(str(APP / f'Sounds/{name}.wav'), 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(rate); output.writeframes(b''.join(frames))
print('Generated bilingual resources, original icon, and four chimes.')
