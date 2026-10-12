#!/usr/bin/env python3
"""Generate bilingual resources and original calendar icon artwork."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

APP = Path(__file__).resolve().parent.parent / 'CalendarSix'
TRANSLATIONS = {
    'Calendar': '日历', 'Calendars': '日历', 'Today': '今天', 'List': '列表', 'Day': '日', 'Month': '月', 'Week': '周',
    'Home Screen Icon': '桌面图标', 'Dynamic Date Icon': '动态日期图标', 'Current Icon': '当前图标', 'Original Icon': '原始图标', 'Update Icon Now': '立即更新图标',
    'Icon changes are unavailable on this device.': '此设备无法切换应用图标。',
    'Unable to change the app icon. Try again.': '无法切换应用图标，请重试。',
    'Icon updates are disabled in the isolated demo.': '独立演示模式下不更新桌面图标。',
    'The icon updates when Calendar opens or returns to the foreground. iOS displays a notice when the icon changes. It cannot refresh while the app is closed.': '打开日历或返回前台时，图标会更新。切换图标时，iOS 会显示系统提示。App 关闭时无法刷新图标。',
    'Add Event': '添加事件', 'Edit Event': '编辑事件', 'Event Details': '事件详情', 'Title': '标题', 'Location': '地点',
    'All-day': '全天', 'all-day': '全天', 'Starts': '开始', 'Ends': '结束', 'Repeat': '重复', 'End Repeat': '结束重复',
    'Start & End': '开始与结束', 'Date': '日期', 'Year': '年', 'Day of Month': '日期',
    'Hour': '小时', 'Minute': '分钟', 'AM/PM': '上午／下午',
    'Never': '永不', 'Every Day': '每天', 'Every Week': '每周', 'Every 2 Weeks': '每两周', 'Every Month': '每月', 'Every Year': '每年',
    'On Date': '于日期', 'Custom': '自定', 'Alert': '提醒', 'Second Alert': '第二次提醒', 'None': '无',
    'At time of event': '事件发生时', '%d minutes before': '提前%d分钟', '1 day before': '提前1天', '2 days before': '提前2天', '1 week before': '提前1周',
    'Availability': '忙闲状态', 'Busy': '忙碌', 'Free': '空闲', 'URL': '网址', 'Notes': '备注', 'Time Zone': '时区',
    'Done': '完成', 'Edit': '编辑', 'Cancel': '取消', 'Back': '返回', 'OK': '好', 'Search': '搜索', 'Clear Search': '清除搜索',
    'No Events': '没有事件', 'No Results': '没有结果', 'Has Events': '有事件', 'Untitled Event': '未命名事件',
    'Previous Month': '上个月', 'Next Month': '下个月', 'Previous Day': '前一天', 'Next Day': '后一天', 'Previous Week': '上周', 'Next Week': '下周',
    'Home': '家庭', 'Work': '工作', 'On My iPhone': '在我的 iPhone 上', 'Color': '颜色', 'Blue': '蓝色', 'Green': '绿色', 'Red': '红色',
    'Orange': '橙色', 'Purple': '紫色', 'Brown': '棕色', 'Calendar Name': '日历名称', 'Add Calendar': '添加日历', 'Edit Calendar': '编辑日历',
    'Show All Calendars': '显示所有日历', 'Hide All Calendars': '隐藏所有日历', 'Read-only': '只读', 'Delete Calendar': '删除日历',
    'Delete this calendar and all its events?': '删除此日历及其中的所有事件？', 'Delete Event': '删除事件', 'Delete this event?': '删除此事件？',
    'Delete Repeating Event': '删除重复事件', 'Save Repeating Event': '存储重复事件', 'Only This Event': '仅此事件', 'All Future Events': '所有将来事件', 'All Events': '所有事件',
    'Settings': '设置', 'Default Calendar': '默认日历', 'Start Week on Monday': '一周从星期一开始', 'App Language': '应用语言', 'Language': '语言',
    'Open Settings': '打开设置', 'System Calendars': '系统日历', 'Connect System Calendars': '连接系统日历', 'Disconnect System Calendars': '断开系统日历',
    'Access': '访问权限', 'Connected': '已连接', 'Not Connected': '未连接', 'Connecting…': '正在连接…', 'Event Reminders': '事件提醒',
    'Notifications': '通知', 'Enable Reminders': '启用提醒', 'Enabled': '已启用', 'Not Enabled': '未启用', 'Disabled in Settings': '已在设置中禁用',
    'Inbox': '收件箱', 'Invitations': '邀请', 'No Invitations': '没有邀请', 'Invitees': '受邀人', 'Open in System Calendar': '在系统日历中打开',
    'Open Location in Maps': '在地图中打开地点', 'ON': '开', 'OFF': '关', '12 AM': '午夜', 'Noon': '中午',
    'Design Meeting': '设计会议', 'Studio': '工作室', 'Review the new calendar design.': '讨论新的日历设计。',
    'Lunch with friends': '与朋友午餐', 'Café': '咖啡馆', 'Alex’s Birthday': 'Alex 的生日', 'Evening Walk': '晚间散步',
    'Enter a title for this event.': '请输入事件标题。', 'Enter a valid http or https URL.': '请输入有效的 http 或 https 网址。',
    'This calendar is read-only.': '此日历为只读。', 'This event has changed. Please reopen it.': '此事件已发生变化，请重新打开。',
    'Calendar access is unavailable. Enable access in Settings.': '无法访问日历，请在设置中允许访问。',
    'Calendar data could not be read. The original file has been preserved.': '无法读取日历数据，原始文件已保留。',
    'Unable to save calendar data. Please try again.': '无法存储日历数据，请重试。',
    'Unable to schedule reminders. Please try again.': '无法安排提醒，请重试。',
    'System calendars are disabled in the isolated demo.': '独立演示模式下无法连接系统日历。',
    'Reminders are disabled in the isolated demo.': '独立演示模式下无法启用提醒。',
    'Enable notifications in Settings to receive event reminders.': '请在设置中允许通知，以接收事件提醒。',
    'Enable notifications in Calendar Settings to receive local event reminders.': '请在日历设置中启用通知，以接收本机事件提醒。',
    'Connect system calendars in Settings to see your iCloud, Exchange, and subscribed calendars.': '在设置中连接系统日历，即可查看你的 iCloud、Exchange 和已订阅日历。',
    'Only calendars already configured on this iPhone appear here. Manage accounts and subscriptions in system Settings. Your local calendars remain on this device.': '此处仅显示已在这部 iPhone 上配置的日历。请在系统设置中管理账户与订阅。本机日历保存在此设备上。',
    'The next 60 local alerts are scheduled. Open Calendar periodically to refresh future reminders. System calendars manage their own alerts.': '最多安排接下来的60次本机提醒。请定期打开日历以更新将来提醒。系统日历管理自身的提醒。',
    'Calendar follows your system or per-app language, just like Weather. English and Simplified Chinese are supported.': '日历与天气一样，跟随系统或单独设置的应用语言，支持英文和简体中文。',
    'Pending invitations from connected calendars appear here.': '已连接日历中待处理的邀请将显示在这里。',
    'Connect system calendars in Settings to view pending invitations.': '请在设置中连接系统日历，以查看待处理邀请。',
    'Open an invitation in System Calendar to accept, decline, or reply. EventKit does not allow this app to send invitation responses.': '请在系统日历中打开邀请以接受、拒绝或回复。EventKit 不允许此应用发送邀请回复。',
    'Calendar reads and edits your system calendar events when you choose to connect system calendars.': '当你选择连接系统日历时，日历将读取和编辑系统日历中的事件。',
}
for language in ['en', 'zh-Hans']:
    directory = APP / f'{language}.lproj'
    directory.mkdir(parents=True, exist_ok=True)
    lines = [f'{json.dumps(key, ensure_ascii=False)} = {json.dumps(value if language == "zh-Hans" else key, ensure_ascii=False)};' for key, value in sorted(TRANSLATIONS.items())]
    (directory / 'Localizable.strings').write_text('\n'.join(lines) + '\n')
    (directory / 'InfoPlist.strings').write_text(
        f'"CFBundleDisplayName" = "{"日历" if language == "zh-Hans" else "Calendar"}";\n'
        '"NSCalendarsFullAccessUsageDescription" = ' + json.dumps(
            TRANSLATIONS['Calendar reads and edits your system calendar events when you choose to connect system calendars.'] if language == 'zh-Hans'
            else 'Calendar reads and edits your system calendar events when you choose to connect system calendars.', ensure_ascii=False) + ';\n')

assets = APP / 'Assets.xcassets'
assets.mkdir(exist_ok=True)
(assets / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
icon_dir = assets / 'AppIcon.appiconset'
icon_dir.mkdir(exist_ok=True)

WEEKDAYS = {
    'en': ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
    'zh-Hans': ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'],
}


def render_icon(day_number=12, weekday=2, language='en'):
    image = Image.new('RGB', (1024, 1024), 'white')
    draw = ImageDraw.Draw(image)
    for y in range(1024):
        if y < 255:
            t = y / 255
            color = tuple(int(a + (b-a)*t) for a,b in zip((240, 104, 97), (163, 14, 18)))
        else:
            t = (y-255)/769
            color = tuple(int(a + (b-a)*t) for a,b in zip((255,255,255), (219,221,224)))
        draw.line((0,y,1024,y), fill=color)
    draw.line((0, 255, 1024, 255), fill=(106, 11, 12), width=5)
    draw.line((0, 262, 1024, 262), fill=(255, 255, 255), width=3)
    font = '/System/Library/Fonts/Helvetica.ttc'
    header = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', 108) if language == 'zh-Hans' else ImageFont.truetype(font, 108, index=1)
    number = ImageFont.truetype(font, 660, index=0)
    title = WEEKDAYS[language][weekday - 1]
    draw.text((512, 143), title, font=header, anchor='mm', fill=(122,21,22))
    draw.text((512, 139), title, font=header, anchor='mm', fill='white')
    # Center the visible digits instead of their unequal font side bearings.
    number_mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(number_mask).text((512, 665), str(day_number), font=number, anchor='mm', fill=255)
    left, _, right, _ = number_mask.getbbox()
    number_offset = round((image.width - left - right) / 2)
    draw.bitmap((number_offset, 0), number_mask, fill=(18,18,20))
    return image


render_icon().save(icon_dir / 'CalendarIcon.png')
(icon_dir / 'Contents.json').write_text(json.dumps({'images': [{'filename':'CalendarIcon.png', 'idiom':'universal', 'platform':'ios', 'size':'1024x1024'}], 'info':{'author':'xcode','version':1}}, indent=2) + '\n')
icon_names = []
for language in WEEKDAYS:
    for weekday in range(1, 8):
        for day in range(1, 32):
            name = f'CalendarDate_{language}_w{weekday}_d{day}'
            directory = assets / f'{name}.appiconset'
            directory.mkdir(exist_ok=True)
            icon = render_icon(day, weekday, language)
            icon.save(directory / 'Icon.png')
            images = [{'filename':'Icon.png', 'idiom':'ios-marketing', 'size':'1024x1024', 'scale':'1x'}]
            for scale in (2, 3):
                filename = f'Icon-{60 * scale}.png'
                icon.resize((60 * scale, 60 * scale), Image.Resampling.LANCZOS).save(directory / filename)
                images.append({'filename':filename, 'idiom':'iphone', 'size':'60x60', 'scale':f'{scale}x'})
            (directory / 'Contents.json').write_text(json.dumps({'images': images, 'info':{'author':'xcode','version':1}}, indent=2) + '\n')
            icon_names.append(name)
(APP.parent / 'scripts' / 'alternate_icons.json').write_text(json.dumps(icon_names, indent=2) + '\n')
print(f'Generated {len(TRANSLATIONS)} bilingual strings, original icon, and {len(icon_names)} date icons')
