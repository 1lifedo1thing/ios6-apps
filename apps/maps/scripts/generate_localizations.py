#!/usr/bin/env python3
"""Generate paired English and Simplified Chinese resources."""
from pathlib import Path
import json, re
ROOT = Path(__file__).resolve().parent.parent / 'MapsSix'
translations = {
'Choose a bookmark':'选择书签',
'Choose a recent search':'选择最近的搜索记录',
'Choose a landmark':'选择地标',
'Locating…':'正在定位…',
'Approximate Location':'当前使用大致位置',
'Public Transport in Apple Maps':'在 Apple 地图中规划公共交通',
'Printing is unavailable. Please try again.':'暂时无法打印。请重试。',
'The map could not be prepared for printing. Check your connection and try again.':'无法准备要打印的地图。请检查网络连接后重试。',
'Maps':'地图', 'Place':'地点', 'Dropped Pin':'放置的图钉', 'Standard':'标准', 'Satellite':'卫星', 'Hybrid':'混合',
'Automatic':'自动', 'Kilometres':'公里', 'Miles':'英里', '%d m':'%d 米', '%.1f mi':'%.1f 英里', '%.1f km':'%.1f 公里', '%d min':'%d 分钟',
'Cancel':'取消', 'Done':'完成', 'Back':'返回', 'OK':'好', 'Close':'关闭', 'On':'开', 'Off':'关',
'Directions':'路线', 'Search or Address':'搜索或地址', 'Clear Search':'清除搜索', 'Bookmarks':'书签', 'Recents':'最近记录', 'Landmarks':'地标',
'Current Location':'当前位置', '3D Map':'三维地图', 'Share Location':'共享位置', 'Map Options':'地图选项', 'Close Map Options':'关闭地图选项',
'Drop Pin':'放置图钉', 'Show Traffic':'显示路况', 'Hide Traffic':'隐藏路况', 'List Results':'结果列表', 'Settings':'设置',
'Map data © Apple and its providers':'地图数据 © Apple 及其提供商', 'Directions to Here':'导航到这里', 'Place Information':'地点信息',
'Start':'起点', 'End':'终点', 'Overview':'总览', 'List':'列表', 'Clear':'清除', 'Route Steps':'路线步骤', 'Previous Step':'上一步', 'Next Step':'下一步',
'Step %d of %d':'第 %d 步，共 %d 步', 'You have arrived.':'您已到达目的地。', 'Recalculating route…':'正在重新规划路线…', 'Loading…':'正在载入…',
'Search for “%@”':'搜索“%@”', 'Info':'信息', 'Search Results':'搜索结果', 'No Bookmarks':'没有书签', 'No Recent Searches':'没有最近记录',
'Select a pin and choose Add Bookmark to save a place.':'选择图钉，再轻点“添加书签”即可保存地点。', 'Clear Recents':'清除最近记录',
'Driving':'驾车', 'Walking':'步行', 'Address or Place':'地址或地点', 'Swap Start and End':'交换起点与终点', 'Calculating…':'正在规划…', 'Route':'规划路线',
'Leave Start empty to use your location, or enter any starting address.':'起点留空可使用当前位置，也可以输入其他出发地址。',
'Directions from Here':'从这里出发', 'Add Bookmark':'添加书签', 'Remove Bookmark':'移除书签', 'Call':'拨打电话', 'Website':'网站',
'Open in Apple Maps':'在 Apple 地图中打开', 'Coordinates':'坐标', 'Remove Pin':'移除图钉', 'No Route':'没有路线',
'Enter a start and destination to get directions.':'输入起点和终点以规划路线。', 'Distances':'距离单位', 'Voice Navigation':'语音导航', 'Flyover':'三维鸟瞰',
'Flyover and traffic coverage vary by region. Map labels and route instructions are supplied by Apple.':'三维鸟瞰和路况的覆盖范围因地区而异。地图标注和路线指引由 Apple 提供。',
'Navigation runs while Maps is open. Use Apple Maps for background and lock-screen guidance.':'导航在地图保持打开时运行。后台和锁屏导航请使用 Apple 地图。',
'MapsSix · Inspired by iOS 6':'MapsSix · 灵感源自 iOS 6', 'No Results':'没有结果',
'Search for a place or drop a pin on the map.':'搜索地点，或在地图上长按放置图钉。',
'Location access is off. Enable it in Settings, or enter a starting address.':'定位权限已关闭。请在设置中开启，或手动输入起点地址。',
'Your location is unavailable. Try again outdoors or enter an address.':'暂时无法获取位置。请在室外重试，或手动输入地址。',
'No Results Found. Try a place name or a full address.':'未找到结果。请尝试地点名称或完整地址。',
'Search is unavailable. Check your connection and try again.':'暂时无法搜索。请检查网络连接后重试。',
'Enter a destination.':'请输入目的地。',
'Waiting for your location. Try again when located, or enter a starting address.':'正在等待定位。请定位成功后重试，或手动输入起点地址。',
'Directions are unavailable. Check both addresses and your connection, then try again.':'暂时无法规划路线。请检查起终点地址和网络连接后重试。',
'Head northwest on The Embarcadero':'沿内河码头路向西北行驶', 'Turn left onto Broadway':'左转进入百老汇街',
'Turn right onto Montgomery Street':'右转进入蒙哥马利街', 'Arrive at Coit Tower':'到达科伊特塔',
'Print Map':'打印地图', 'Report a Problem':'报告问题', 'Print':'打印', 'Start Navigation':'开始导航', 'End Navigation':'结束导航',
}
for language in ['en', 'zh-Hans']:
    folder=ROOT/f'{language}.lproj';folder.mkdir(exist_ok=True)
    encode=lambda text:json.dumps(text,ensure_ascii=False)
    (folder/'Localizable.strings').write_text('\n'.join(f'{encode(k)} = {encode(v if language=="zh-Hans" else k)};' for k,v in sorted(translations.items()))+'\n')
    display='地图' if language=='zh-Hans' else 'Maps'
    permission='地图使用您的位置显示当前位置、查找附近地点，并在应用打开时提供路线指引。' if language=='zh-Hans' else 'Maps uses your location to show your position, find nearby places, and guide you along a route while the app is open.'
    (folder/'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = {encode(display)};\n"NSLocationWhenInUseUsageDescription" = {encode(permission)};\n')
print(f'Generated {len(translations)} keys in both languages')
