#!/usr/bin/env python3
"""Generate matching English/Simplified Chinese UI and privacy resources."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent.parent / "CameraSix"
TRANSLATIONS = {
"%d item": "%d 个项目", "%d items": "%d 个项目", "%d of %d": "第 %d 个，共 %d 个",
"A local copy is always kept in Camera Roll. Photos permission is requested when saving.": "拍摄结果始终保留在相机胶卷中。保存至系统照片时才会请求照片权限。",
"AE/AF Lock": "自动曝光/自动对焦锁定", "Auto": "自动", "Auto-enhance": "自动增强",
"Back camera": "后置摄像头", "Camera": "相机", "Camera Roll": "相机胶卷", "Camera Settings": "相机设置",
"Camera access is disabled. Enable Camera in Settings.": "相机权限已关闭。请在设置中允许访问相机。",
"Camera follows your iPhone language: English or Simplified Chinese.": "相机跟随 iPhone 的语言设置，支持英文和简体中文。",
"Camera interrupted. Return to the app to resume.": "相机已被中断。返回应用即可恢复。",
"Camera unavailable. Try reopening the app.": "相机暂时不可用。请尝试重新打开应用。",
"Camera/Video switch": "照片/录像切换", "Cancel": "取消", "Crop 4:3": "裁剪为 4:3",
"Delete": "删除", "Delete local copy?": "删除本地副本？", "Done": "完成", "Edit": "编辑",
"Edit Photo": "编辑照片", "Edits are saved as a new photo.": "编辑结果将另存为新照片。",
"Finish panorama": "完成全景拍摄", "Flash": "闪光灯", "Flash is unavailable.": "闪光灯暂时不可用。",
"Front camera": "前置摄像头", "Grid": "网格", "HDR": "HDR",
"HDR combines three exposures. Keep iPhone steady. Flash is disabled while HDR is on.": "HDR 合成三张不同曝光的照片。请保持 iPhone 稳定。启用 HDR 时闪光灯会关闭。",
"Import from Photos": "从照片导入", "Importing…": "正在导入…", "Keep Normal Photo": "保留正常曝光照片",
"Keep the arrow on the line and pan slowly.": "保持箭头沿着横线，缓慢移动。", "Left to right": "从左向右",
"Microphone access is disabled. Enable Microphone in Settings to record sound.": "麦克风权限已关闭。请在设置中允许访问麦克风，以录制声音。",
"Next": "下一张", "No Photos or Videos": "没有照片或视频", "OFF": "关闭", "OK": "好", "ON": "开启",
"Off": "关闭", "On": "开启", "Open Settings": "打开设置", "Opening camera…": "正在打开相机…", "Options": "选项",
"Panorama": "全景", "Panorama could not be aligned. Pan slowly across a detailed scene.": "全景图像未能对齐。请对准细节丰富的场景缓慢移动。",
"Panorama requires motion sensors.": "全景拍摄需要运动传感器。", "Permissions": "权限", "Photo": "照片", "Photo mode": "照片模式",
"Photos and videos you take appear here.": "拍摄的照片和视频将显示在这里。", "Previous": "上一张", "Record video": "开始录像",
"Reverse panorama direction": "反转全景拍摄方向", "Revert": "还原", "Right to left": "从右向左", "Rotate": "旋转",
"Save": "保存", "Save to Photos": "保存到照片", "Saving": "保存", "Share": "分享",
"Saved in Camera Roll, but saving to Photos failed. You can retry from Camera Roll.": "已保存至相机胶卷，但未能保存至系统照片。可在相机胶卷中重试。",
"Saved in Camera Roll. Allow Photos access in Settings to save to your photo library.": "已保存至相机胶卷。请在设置中允许访问照片，以保存至系统照片图库。",
"Simulator uses an illustrated demo scene. Test camera, microphone, flash, and panorama motion on an iPhone.": "模拟器使用绘制的演示场景。请在 iPhone 上验证摄像头、麦克风、闪光灯和全景扫描。",
"Simulator • Demo Viewfinder": "模拟器 · 演示取景", "Start panorama": "开始全景拍摄", "Stop recording": "停止录像",
"Switch camera": "切换摄像头", "Take photo": "拍照", "Take photo while recording": "录像时拍照",
"Tap the shutter and move iPhone in the direction of the arrow.": "轻点快门，沿箭头方向移动 iPhone。",
"The photo could not be captured. Please try again.": "未能拍摄照片。请重试。",
"The photo could not be processed. Please try again.": "未能处理照片。请重试。",
"The photo could not be saved. Please check available storage.": "未能保存照片。请检查可用存储空间。",
"The video could not be recorded. Please try again.": "未能录制视频。请重试。",
"The video could not be saved. Please check available storage.": "未能保存视频。请检查可用存储空间。",
"This removes the copy in Camera Roll. Photos library copies are kept.": "此操作仅移除相机胶卷中的本地副本。系统照片图库中的副本将保留。",
"Unable to change zoom.": "未能调整缩放。", "Unable to focus the camera.": "未能调整对焦。",
"Unable to switch cameras. Please try again.": "未能切换摄像头。请重试。",
"Video": "视频", "Video mode": "录像模式", "Zoom": "缩放",
"Viewfinder. Tap to focus, hold to lock focus, pinch to zoom.": "取景器。轻点对焦，长按锁定对焦，双指缩放。",
"The item could not be deleted.": "未能删除该项目。", "Saved to Photos.": "已保存到照片。",
"Allow Photos access in Settings to save this item.": "请在设置中允许访问照片，以保存此项目。",
"Saving to Photos failed. Please try again.": "未能保存至照片。请重试。",
"Some items could not be imported. Please try again.": "部分项目未能导入。请重试。",
}

PRIVACY = {
"CFBundleDisplayName": ("Camera", "相机"),
"NSCameraUsageDescription": ("Camera uses the camera to take photos, record videos, and capture panoramas.", "相机需要使用摄像头来拍摄照片、录制视频和拍摄全景。"),
"NSMicrophoneUsageDescription": ("Camera uses the microphone to record sound with your videos.", "相机需要使用麦克风来录制视频中的声音。"),
"NSPhotoLibraryAddUsageDescription": ("Camera saves the photos and videos you take to your photo library.", "相机需要将拍摄的照片和视频保存到你的照片图库。"),
"NSPhotoLibraryUsageDescription": ("Camera lets you choose photos and videos to view in your camera roll.", "相机允许你选择照片和视频并在相机胶卷中浏览。"),
}

def write_strings(path, pairs):
    path.write_text("\n".join(f"{json.dumps(key,ensure_ascii=False)} = {json.dumps(value,ensure_ascii=False)};" for key,value in sorted(pairs.items())) + "\n")

for language in ["en", "zh-Hans"]:
    folder = ROOT / (language + ".lproj")
    folder.mkdir(exist_ok=True)
    write_strings(folder / "Localizable.strings", {key: key if language == "en" else value for key,value in TRANSLATIONS.items()})
    write_strings(folder / "InfoPlist.strings", {key: value[0 if language == "en" else 1] for key,value in PRIVACY.items()})

# Foundation distinguishes writing systems; aliases keep native privacy prompts in Simplified Chinese too.
for language in ["zh", "zh-Hant"]:
    folder = ROOT / (language + ".lproj")
    folder.mkdir(exist_ok=True)
    write_strings(folder / "InfoPlist.strings", {key: value[1] for key,value in PRIVACY.items()})
print(f"Generated {len(TRANSLATIONS)} strings in each language")
