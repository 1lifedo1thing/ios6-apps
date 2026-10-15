#!/usr/bin/env python3
"""Generate English and Simplified Chinese interface and privacy strings."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parent.parent/'PhotosSix'
ZH={
'Mail is not configured. Use More… to choose another app.':'尚未配置邮件。请使用“更多…”选择其他应用。','Messages is unavailable. Use More… to choose another app.':'信息暂不可用。请使用“更多…”选择其他应用。','Use More… to share large attachments.':'请使用“更多…”分享较大的附件。','ON':'开启','OFF':'关闭','No Photo Library Access':'没有照片图库访问权限','Photos':'照片','Albums':'相簿','Camera Roll':'相机胶卷','Videos':'视频','Photo Stream':'照片流','Places':'地点',
'Edit':'编辑','Done':'完成','Cancel':'取消','Save':'保存','New Album':'新建相簿','Rename Album':'重命名相簿','Album Name':'相簿名称',
'Delete Album':'删除相簿','Delete Album?':'删除相簿？','Deleting an album keeps its photos in Camera Roll.':'删除相簿后，照片仍会保留在相机胶卷中。',
'Delete':'删除','Remove':'移除','Share':'分享','Add To':'添加到','Add To Album':'添加到相簿','Add Photos':'添加照片',
'Create an album first.':'请先新建一个相簿。','Remove from Album?':'从相簿移除？','These items will stay in Camera Roll.':'这些项目仍会保留在相机胶卷中。',
'Delete from Photo Library?':'从照片图库删除？','These items will be deleted from the system photo library on all synced devices.':'这些项目将从系统照片图库及所有同步设备中删除。',
'This item will be deleted from the system photo library on all synced devices.':'此项目将从系统照片图库及所有同步设备中删除。',
'Demo Library • Original Illustrations':'演示图库 · 原创插画','No Photos or Videos':'没有照片或视频','Take a Photo':'拍照',
'Photo':'照片','Video':'视频','Previous':'上一张','Next':'下一张','Slideshow':'幻灯片','Photo Information':'照片信息',
'Slideshow Options':'幻灯片选项','Show Each Photo For':'每张照片显示','Seconds':'秒','%d s':'%d 秒','%d seconds':'%d 秒','Shuffle':'随机播放','Repeat':'重复播放',
'Start Slideshow':'开始播放幻灯片','Stop Slideshow':'停止播放幻灯片','%d / %d':'%d / %d','%d of %d':'第 %d 个，共 %d 个','%d selected':'已选择 %d 个',
'%d item':'%d 个项目','%d items':'%d 个项目','%d photos':'%d 张照片','%d videos':'%d 个视频',
'Loading…':'正在载入…','Saving…':'正在保存…','Preparing…':'正在准备…','Try Again':'重试',
'Edit Photo':'编辑照片','Trim Video':'修剪视频','Edits are saved as a new copy. The original is kept.':'编辑结果将另存为新副本，原件保留。',
'Rotate':'旋转','Enhance':'自动增强','Red-eye':'红眼','Crop':'裁剪','Revert':'还原','Square':'正方形',
'Tap each red eye in the photo.':'请轻点照片中每只出现红眼的眼睛。','Drag to reposition the crop.':'拖动以调整裁剪位置。','Start':'起点','End':'终点','Preview':'预览',
'Mail':'邮件','Message':'信息','More…':'更多…','Copy':'拷贝','Print':'打印','Wallpaper':'墙纸',
'To use a photo as wallpaper, open Settings > Wallpaper > Add New Wallpaper and choose it from Photos.':'如要设为墙纸，请打开“设置”>“墙纸”>“添加新墙纸”，从照片中选取。',
'Select photos to print.':'请选择照片进行打印。','No Location Information':'没有位置信息','Photos with saved locations appear on this map.':'包含拍摄位置的照片将显示在地图上。',
'View Photos':'查看照片','Close':'关闭','Map':'地图','Satellite':'卫星','Settings':'设置','Photo Library':'照片图库',
'Selected Photos Access':'已授权选定照片','Selected Photos Access • Manage':'已授权选定照片 · 管理','Full Photo Library Access':'完整照片图库访问权限',
'Manage Selected Photos':'管理选定照片','Open Settings':'打开设置','Open Camera':'打开相机','CameraSix':'相机',
'CameraSix and PhotosSix share the system photo library. Enable Save to Photos in CameraSix. Local-only captures remain in CameraSix until saved.':'相机与照片共享系统照片图库。请在相机中开启“保存到照片”。仅在本地保存的内容需先存入系统照片图库。',
'Language':'语言','Uses the system or app language: English and Simplified Chinese. Chinese variants use Simplified Chinese; other languages use English.':'跟随系统或应用语言，支持英语和简体中文。所有中文变体使用简体中文，其他语言回退为英语。',
'Your Photos, Just Like Before':'熟悉的照片，熟悉的模样','Browse the photos and videos on your iPhone. CameraSix captures appear here after saving to Photos.':'浏览 iPhone 中的照片和视频。相机拍摄的内容存入系统照片图库后，会显示在这里。',
'Open Photo Library':'打开照片图库','Allow Photos access in Settings to use your library.':'请在设置中允许访问照片，以使用图库。',
'This item could not be downloaded. Check your connection and try again.':'未能下载此项目。请检查网络连接后重试。','Changes could not be saved. Please try again.':'未能保存更改。请重试。',
'Enter an album name.':'请输入相簿名称。','Install CameraSix to take photos. Both apps use the system photo library.':'请安装 CameraSix 以拍摄照片。两个应用通过系统照片图库共享内容。',
'The photo is not available. With limited access, include it in your selection in Settings.':'照片暂不可用。若使用选定照片权限，请在设置中将其加入授权范围。',
'My Photo Stream has been retired by Apple. Available iCloud Shared Albums appear here with full Photos access.':'Apple 已停止“我的照片流”服务。授予完整照片权限后，可用的 iCloud 共享相簿会显示在这里。',
'Summer 2012':'2012 年夏天','A Weekend Away':'周末出游','OK':'好','Move Up':'上移','Move Down':'下移',
'4:3':'4:3','3:4':'3:4','16:9':'16:9'
}
PRIVACY={
'CFBundleDisplayName':('Photos','照片'),
'NSPhotoLibraryUsageDescription':('Photos displays your photos, videos, albums, and saved locations, and lets you organize and edit them.','照片需要访问你的照片、视频、相簿和保存的位置，以便浏览、整理和编辑。'),
'NSPhotoLibraryAddUsageDescription':('Photos saves edited photos and trimmed videos to your photo library.','照片需要将编辑后的照片和修剪的视频保存到你的照片图库。')}
def write(path,pairs):
    path.parent.mkdir(exist_ok=True)
    path.write_text('\n'.join(f'{json.dumps(k,ensure_ascii=False)} = {json.dumps(v,ensure_ascii=False)};' for k,v in sorted(pairs.items()))+'\n')
for language in ['en','zh-Hans']:
    write(ROOT/(language+'.lproj')/'Localizable.strings',{k:k if language=='en' else v for k,v in ZH.items()})
    write(ROOT/(language+'.lproj')/'InfoPlist.strings',{k:v[language!='en'] for k,v in PRIVACY.items()})
for language in ['zh','zh-Hant']:
    write(ROOT/(language+'.lproj')/'InfoPlist.strings',{k:v[1] for k,v in PRIVACY.items()})
print(f'Generated {len(ZH)} bilingual strings')
