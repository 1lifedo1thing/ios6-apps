#!/usr/bin/env python3
"""Generate original paper/leather artwork, a classic icon, and bilingual resources."""
from pathlib import Path
import json
import random
from PIL import Image, ImageDraw, ImageFilter

APP = Path(__file__).resolve().parent.parent / 'RemindersSix'
TRANSLATIONS = {
'Reminders':'提醒事项', 'Reminder':'提醒事项', 'Lists':'列表', 'List':'列表', 'Details':'详细信息',
'Edit':'编辑', 'Done':'完成', 'Cancel':'取消', 'Back':'返回', 'OK':'好', 'Delete':'删除',
'New Reminder':'新提醒事项', 'Add Reminder':'添加提醒事项', 'No Reminders':'没有提醒事项', 'No Completed Reminders':'没有已完成的提醒事项',
'Completed reminders appear here.':'已完成的提醒事项会显示在这里。', 'Tap + to add a reminder.':'轻点 + 添加提醒事项。',
'Completed':'已完成', 'Today':'今天', 'Search':'搜索', 'Clear search':'清除搜索', 'No Results':'没有结果',
'Create New List…':'创建新列表…', 'New List':'新建列表', 'Rename List':'重新命名列表', 'List Name':'列表名称',
'Choose a name for your list.':'为你的列表选择一个名称。', 'On My iPhone':'在我的 iPhone 上', 'Accounts':'账户',
'System Reminders':'系统提醒事项', 'Connected':'已连接', 'Not Connected':'未连接',
'Connect System Reminders':'连接系统提醒事项', 'Disconnect System Reminders':'断开系统提醒事项',
'Refresh System Reminders':'刷新系统提醒事项', 'Create in System Reminders':'在系统提醒事项中创建',
'Local lists stay on this iPhone. Connected accounts use the system\'s Reminders sync.':'本地列表保存在此 iPhone 上。已连接账户通过系统的提醒事项同步。',
'Disconnecting keeps your system reminders intact.':'断开连接会保留系统中的提醒事项。',
'Preview data is separate from your saved reminders.':'预览数据与你保存的提醒事项相互独立。',
'Remind Me On a Day':'在指定日期提醒我', 'Remind Me At a Location':'在指定位置提醒我',
'Due date':'提醒日期', 'Repeat':'重复', 'Never':'永不', 'Every Day':'每天', 'Every Week':'每周',
'Every Two Weeks':'每两周', 'Every Month':'每月', 'Every Year':'每年',
'Priority':'优先级', 'None':'无', 'Low':'低', 'Medium':'中', 'High':'高', 'Notes':'备注',
'Location':'位置', 'Choose a Location':'选择位置', 'When I Arrive':'当我到达时', 'When I Leave':'当我离开时',
'Current Location':'当前位置', 'Enter an Address':'输入地址',
'You will be reminded when you arrive at or leave the selected place.':'到达或离开所选位置时，你会收到提醒。',
'ON':'开', 'OFF':'关', 'Complete':'标记为已完成', 'Mark Incomplete':'标记为未完成',
'Delete %@':'删除%@', 'Complete %@':'将%@标记为已完成', 'Mark %@ incomplete':'将%@标记为未完成',
'Arriving at %@':'到达%@时', 'Leaving %@':'离开%@时', 'Move up':'上移', 'Move down':'下移',
'Next list':'下一个列表', 'Previous list':'上一个列表', 'Open Settings':'打开设置',
'Delete Reminder?':'删除提醒事项？', 'Delete List?':'删除列表？', 'All reminders in this list will be deleted.':'此列表中的所有提醒事项都将被删除。',
"Couldn't save reminders. Please try again.":'无法保存提醒事项，请重试。',
"Couldn't read saved reminders. Your file has been preserved.":'无法读取保存的提醒事项，原文件已保留。',
'Access is unavailable. Enable it in Settings and try again.':'无法获得访问权限，请在设置中开启后重试。',
'This list is read-only.':'此列表为只读。', 'This reminder or list is no longer available.':'此提醒事项或列表已不存在。',
'Keep at least one local list.':'请至少保留一个本地列表。',
'Some alerts could not be scheduled. Keep fewer than 60 date alerts and 20 location alerts.':'部分提醒无法安排，请保留少于 60 个日期提醒和 20 个位置提醒。',
"Couldn't find this location. Try a more specific address.":'无法找到此位置，请尝试更详细的地址。',
"This system reminder has an advanced repeat rule. Edit its date and repeat in Apple's Reminders.":'此系统提醒事项使用高级重复规则，请在苹果的“提醒事项”中编辑其日期和重复设置。',
'Enable notifications in Settings for reminder alerts.':'请在设置中允许通知，以接收提醒。',
'Enable location access in Settings for location alerts.':'请在设置中允许位置访问，以接收位置提醒。',
'Reminders reads and edits system reminders only when you choose to connect your accounts.':'仅当你选择连接账户时，提醒事项才会读取和编辑系统提醒事项。',
'Reminders uses your location for alerts when you arrive at or leave a place.':'提醒事项使用你的位置，在你到达或离开某个地点时发送提醒。',
}
for language in ['en', 'zh-Hans']:
    folder = APP / f'{language}.lproj'
    folder.mkdir(parents=True, exist_ok=True)
    (folder/'Localizable.strings').write_text('\n'.join(f'{json.dumps(key, ensure_ascii=False)} = {json.dumps(value if language == "zh-Hans" else key, ensure_ascii=False)};' for key, value in TRANSLATIONS.items())+'\n')
    info = {'CFBundleDisplayName':'Reminders',
    'NSRemindersFullAccessUsageDescription':'Reminders reads and edits system reminders only when you choose to connect your accounts.',
    'NSLocationWhenInUseUsageDescription':'Reminders uses your location for alerts when you arrive at or leave a place.'}
    (folder/'InfoPlist.strings').write_text('\n'.join(f'{json.dumps(key)} = {json.dumps(TRANSLATIONS.get(value,value) if language=="zh-Hans" else value,ensure_ascii=False)};' for key,value in info.items())+'\n')

assets=APP/'Assets.xcassets'
assets.mkdir(parents=True,exist_ok=True)
(assets/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
rng = random.Random(600)
side = 512

# Two pixels per point keep the grain fine on both compact and high-density displays.
paper = Image.new('RGB', (side, side))
pixels = paper.load()
for y in range(side):
    for x in range(side):
        grain = rng.choice([-2, -1, 0, 0, 0, 1, 2])
        pixels[x, y] = (244 + grain, 244 + grain, 239 + grain)
draw = ImageDraw.Draw(paper)
for _ in range(1400):
    x, y = rng.randrange(side), rng.randrange(side)
    dx, dy = rng.randrange(3, 12), rng.randrange(-2, 3)
    color = rng.choice([(241, 241, 236), (246, 246, 241)])
    for ox in [-side, 0, side]:
        for oy in [-side, 0, side]:
            draw.line((x+ox, y+oy, x+dx+ox, y+dy+oy), fill=color)
paper = paper.filter(ImageFilter.GaussianBlur(0.35))

# Larger periodic cells and directional highlights survive the live mirror's downsampling.
cell_count = 64
cell_size = side / cell_count
seeds = {(x, y): ((x + rng.uniform(.15, .85)) * cell_size,
                   (y + rng.uniform(.15, .85)) * cell_size)
         for y in range(cell_count) for x in range(cell_count)}
leather = Image.new('RGB', (side, side))
pixels = leather.load()
for y in range(side):
    for x in range(side):
        cell_x, cell_y = int(x / cell_size), int(y / cell_size)
        distances = []
        for cy in range(cell_y - 1, cell_y + 2):
            for cx in range(cell_x - 1, cell_x + 2):
                sx, sy = seeds[cx % cell_count, cy % cell_count]
                sx += (cx // cell_count) * side
                sy += (cy // cell_count) * side
                distances.append(((x - sx) ** 2 + (y - sy) ** 2, sy))
        distances.sort()
        edge = min(1, (distances[1][0] ** .5 - distances[0][0] ** .5) / 2.2)
        light = (y - distances[0][1]) / cell_size
        value = round(30 + edge * 23 - light * 8 + rng.uniform(-1.2, 1.2))
        pixels[x, y] = (value, value, value - 1)
leather = leather.filter(ImageFilter.GaussianBlur(0.3))
for name, img in [('PaperTexture', paper), ('LeatherTexture', leather)]:
    folder = assets / f'{name}.imageset'
    folder.mkdir(exist_ok=True)
    filename = f'{name}.png'
    img.save(folder / filename, optimize=True)
    (folder / 'Contents.json').write_text(json.dumps({
        'images': [{'idiom': 'universal', 'scale': '2x', 'filename': filename}],
        'info': {'author': 'xcode', 'version': 1}}) + '\n')

# The reviewed imagegen source is versioned with the project, never redrawn as a placeholder.
source = APP.parent / 'artwork' / 'AppIcon-source.png'
icon = Image.open(source).convert('RGB').resize((1024, 1024), Image.Resampling.LANCZOS)
folder = assets / 'AppIcon.appiconset'
folder.mkdir(exist_ok=True)
icon.save(folder / 'AppIcon.png', optimize=True)
(folder / 'Contents.json').write_text(json.dumps({
    'images': [{'filename': 'AppIcon.png', 'idiom': 'universal',
                'platform': 'ios', 'size': '1024x1024'}],
    'info': {'author': 'xcode', 'version': 1}}) + '\n')
print(f'Generated fine material tiles, the reviewed icon, and {len(TRANSLATIONS)} localization keys.')
