# ClockSix

A native iPhone recreation of the iOS 6 Clock app for iOS 17 and later, with World Clock, Alarm, Stopwatch, and Timer. Open `ClockSix.xcodeproj` independently, or select `ClockSix` in the collection's `iOS6Apps.xcworkspace`.

## Design

The blue-gray beveled navigation bars, silver gradient rows, day/night analog dials, blue pinstripe world-map surface, black stopwatch instrument, glossy controls, classic ON/OFF switches, and four-tab bar follow the iPhone version of iOS 6. Alarm editing uses a full-screen panel with grouped settings and shaded picker wheels. The picker has an inset metal rim, cylindrical lighting, dimensional column separators, a continuous selection band, and stationary duration units. Each screen's body material extends behind both the status and bottom safe areas; the tab bar paints only its own panel. Landscape and modern safe areas adapt that composition to current displays. The app uses the real system status bar.

Read the collection's [shared design language](../../docs/design-language.md). Clock keeps its specialized instrument layouts and adopts classic grouped settings for alarm editing and sound selection. All map silhouettes, icon artwork, and synthesized chimes are original; historical screenshots are references only.

References:

- [Apple iPhone User Guide for iOS 6, chapter 19](https://cdsassets.apple.com/live/6GJYWVAV/user/ma1658_iphone_ios6_user_guide.pdf).
- [Martin Nobel's iPhone 5 / iOS 6.0 screenshots](https://www.martinnobel.com/techresearch/ios-6-screenshots).
- [iOS 6 timer reference from February 2013](https://sharechair.wordpress.com/2013/02/11/how-to-stop-the-music-with-a-timer-on-your-iphone-or-ipad/).
- [iClarified's iOS 6 and iOS 7 comparison](https://www.iclarified.com/33970/ios-6-vs-ios-7-a-side-by-side-comparison-image-gallery).

## Features

- World Clock: 34 offline cities with bilingual names and searches, live analog/digital times, day/night faces, relative dates, add/delete/reorder, and persistence. Time zones use Foundation's current time-zone database, including daylight saving and fractional offsets.
- Alarm: add/edit/delete, hour/minute picker (English AM/PM, Chinese 24-hour), selected weekday repeats, sound preview, snooze, custom labels, downloaded Music-library song selection, classic enable switches, and persisted settings. One-shot alarms disable after firing. Snooze lasts nine minutes and survives process restart.
- Stopwatch: tenths of a second, start/stop/resume, ordered lap durations, reset, and persisted running/paused state. Backgrounding does not interrupt elapsed-time accounting.
- Timer: hour/minute selection, pause/resume/cancel, finish panel, sound selection, and persisted absolute deadline. Zero duration cannot start.
- Reminders: public `UserNotifications` calendar/time-interval scheduling, bundled custom sounds, localized notification actions, foreground ringing, and Settings recovery when permission is denied.

## Language adaptation

Clock follows Weather: the first system or per-app preferred language selects the interface. Chinese variants use Simplified Chinese; English and unsupported languages use English. Localized resources cover controls, city names, weekday/relative-date formatting, sound names, accessibility labels, notification content/actions, errors, and the Home Screen name. User-written alarm labels and stored state survive language changes. Supported language choice is available in the system's per-app settings after configuring more than one device language.

## Build and test

```sh
xcodebuild -project ClockSix.xcodeproj -scheme ClockSix \
  -destination 'platform=iOS Simulator,name=iPhone Air' \
  -derivedDataPath /tmp/ClockSix-DerivedData build

xcodebuild -project ClockSix.xcodeproj -scheme ClockSix \
  -destination 'platform=iOS Simulator,name=iPhone Air' \
  -derivedDataPath /tmp/ClockSix-DerivedData \
  -parallel-testing-enabled NO test
```

Use a temporary DerivedData directory if a synced project folder adds Finder metadata that prevents code signing. Physical-device builds require your own signing team.

Run the simulator mirror from the collection root and keep its terminal alive:

```sh
zsh apps/clock/scripts/serve_sim.sh <simulator-udid>
```

Open the URL printed by `serve-sim` in the Codex in-app browser. The helper is scoped to the selected simulator and cleaned up on terminal exit. If input is unavailable, use the official `serve-sim repair-input -d <simulator-udid>` command, restart the mirror, and verify a visible interaction.

Regenerate the dependency-free project with `python3 scripts/create_project.py`. Regenerate original artwork, chimes, and strings with `python3 scripts/generate_resources.py` (requires Pillow).

UI tests use a separate `ClockSix-UITests` defaults suite. `--uitesting --reset` resets only that test suite. The normal app stores data in its own defaults and never clears it on launch.

## Platform differences

This is a modern iPhone app inspired by iOS 6, not an installation of the historical OS. Keyboards, permission prompts, and system notifications use the current OS appearance. The iPad-specific iOS 6 map/weather dashboard is outside this iPhone recreation.

Background reminders are ordinary local notifications, not the privileged built-in Clock alarm service. Delivery and sound follow notification permission, Silent Mode, Focus, and system policy; the app does not promise to bypass those settings. Foreground alarms show the classic panel and loop the selected chime. Four original sound patterns reproduce the character of classic tones without copying Apple's recordings. Downloaded, unprotected Music-library songs can be selected on a physical iPhone, after permission, and played for foreground alarms. Background song alarms use the selected bundled tone, and a missing or inaccessible song falls back to that tone. The system music picker keeps the current OS appearance. Simulator cannot access a device's music library; the app presents a localized recovery panel there.

`Stop Playing` can interrupt other audio through a public audio-session activation while Clock is in the foreground. In the background it delivers a silent timer notification; iOS does not grant this app scheduled control of another app's playback. This difference is also explained on the sound-selection screen.

Up to 60 calendar notification requests are scheduled, reserving system capacity for a timer and snooze. Each selected repeat weekday uses one request. Exceeding that budget presents a localized error. All app data remains available for editing.

See the [verification record](docs/verification.md) for tested devices, results, and screenshots.
