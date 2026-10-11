# ClockSix verification

Verified on 11 October 2026. This record describes the native iPhone implementation, rather than historical iOS binaries.

## Test environments

The project builds with Xcode 27.0 (27A266a) for arm64 simulators, with a deployment target of iOS 17.0. Build products are kept in `/private/tmp/ClockSix-DerivedData` so file-provider metadata in the source checkout does not affect code signing.

| Device | Runtime | Initial complete regression |
| --- | --- | --- |
| iPhone Air | iOS 26.2 | 26 passed, 0 failed, 0 skipped |
| iPhone SE (3rd generation) | iOS 17.5 | 26 passed, 0 failed, 0 skipped |

Result bundles are stored in `/Users/yinyueyang/Library/Developer/XcodeBuildMCP/workspaces/ios6-apps-5274783ae1de/result-bundles/`:

- Air: `test_sim_2026-10-11T12-59-40-937Z_pid29867_ce8a96a6.xcresult`.
- SE: `test_sim_2026-10-11T13-02-16-335Z_pid29867_8803e38f.xcresult`.

The final compact alarm-row adjustment was then rechecked with the alarm editing/toggle/reopen/delete test (including a row-spacing assertion) and large-text navigation test on both devices: two passed per device, zero failures or skips. Result bundles:

- Air: `test_sim_2026-10-11T13-05-55-726Z_pid29867_7dcf0784.xcresult`.
- SE: `test_sim_2026-10-11T13-04-52-664Z_pid29867_9ed97e17.xcresult`.

## Coverage

The suite currently contains 16 unit tests and 11 UI tests. The initial complete runs above used 10 UI tests; the bilingual picker-selection test was added for the refinement below. Unit tests cover language selection, bilingual city search and distinct city identities, fractional offsets and date-line changes, daylight-saving transitions, next repeat dates, notification trigger/sound/category construction, reminder capacity, persisted alarms and selected songs, nine-minute snooze restoration, duplicate delivery suppression, stopwatch laps and restart restoration, and timer expiry/pause/resume/cancel boundaries.

UI tests exercise:

- English city search, add, reorder, delete, empty state, and cancel.
- Alarm time wheels, weekday repeats, sound, label, save, enable switch, reopen, and delete.
- Chinese variants mapped to Simplified Chinese, Chinese city search, and custom labels/state preserved when relaunching in English.
- Stopwatch start, lap, pause, relaunch, resume, and reset.
- Timer sound selection, pause, resume, cancel, and disabled zero-duration start.
- Timer expiry, dismissal, and a second successful start and expiry.
- All four tabs in landscape, compact safe areas, French-to-English fallback, and large-text alarm navigation.
- Simulator music-library recovery and continued sound selection.
- A real 10-second `UNUserNotificationCenter` timer delivered as a visible SpringBoard notification while the app is on the Home Screen, followed by foreground completion and dismissal. This test uses real reminder scheduling, rather than a notification mock.

Normal app data and UI-test data use separate defaults suites. Test reset never clears the normal app's stored cities, alarms, stopwatch, or timer.

## Compatibility repairs

The oldest supported runtime was tested explicitly. Native `UIPickerView` components use guarded row indices and clear delegates during teardown, avoiding an iOS 17 SwiftUI wheel-picker removal crash. Stopwatch rows capture observable lap data before constructing child views; decorative empty rows are drawn separately. Timer controls remain outside scrolling content. The classic finish panel uses a transparent system full-screen presentation so dismissal releases touch handling correctly. The main tab layout ignores the keyboard safe-area adjustment, preventing tab movement while a city-search keyboard is dismissed. Light settings screens request a light color scheme for readable system status-bar text. Standalone alarm switches omit their visual label from the layout while retaining their accessibility label, keeping alarm rows compact.

## Picker and safe-area refinement

The browser feedback requested a more detailed timer wheel panel, body-material continuity below the tab bar, and retained wheel-column separators. The shared [design language](../../../docs/design-language.md) now applies top/bottom continuity to specialized screens as well as Notes/settings frames.

The picker uses an inset beveled rim, cylindrical shading, a narrow selection band, fixed bilingual duration units, and dimensional metal column separators. Public `UIPickerView` row views preserve native scrolling, accessibility, and row selection. Decorative overlays do not intercept input. The root tab-bar background explicitly respects safe-area edges so the current screen's body remains visible below it.

Affected regression on iPhone Air/iOS 26.2: five existing UI tests passed, followed by the new bilingual picker test (one passed). On iPhone SE/iOS 17.5, the same six tests passed together. Zero failures or skips. Coverage includes repeat/sound/label/time editing, cancel/reopen, large text, all four tabs in landscape, timer pause/resume/cancel/zero duration, and repeated expiry/dismissal. The new bilingual test selects 2 hours 35 minutes, starts/cancels the timer, and checks the restored duration and minute-wheel value in both languages.

Result bundles:

- Air affected flows: `test_sim_2026-10-11T13-12-56-589Z_pid29867_3f9cfdcc.xcresult`.
- Air bilingual selection: `test_sim_2026-10-11T13-14-45-049Z_pid29867_09e54777.xcresult`.
- SE affected flows and bilingual selection: `test_sim_2026-10-11T13-15-10-400Z_pid29867_728e92d1.xcresult`.

The final column separators were checked again with the bilingual timer and English alarm editing flows: two passed on each device, with zero failures or skips. Screenshots are captured after canceling and restoring the chosen duration, so a still frame represents the settled wheel values rather than an in-flight accessibility adjustment.

- Air final separators: `test_sim_2026-10-11T13-19-04-887Z_pid29867_fd86025e.xcresult`.
- SE final separators: `test_sim_2026-10-11T13-20-35-315Z_pid29867_0ac2591e.xcresult`.

Refinement screenshots: [final live timer with column separators](screenshots/picker-and-safe-areas/browser-timer.jpg), [world-clock top/bottom continuity](screenshots/picker-and-safe-areas/browser-world.jpg), [iPhone Air](screenshots/picker-and-safe-areas/iphone-air/), and [iPhone SE](screenshots/picker-and-safe-areas/iphone-se/). These captures supersede the initial picker and bottom-strip appearance shown in earlier screenshots.

## Static and resource checks

- Strict recursive `swift-format` lint passes for app, unit tests, and UI tests.
- Project, app plist, and both localized string resources pass `plutil` validation.
- Localization keys have matching English and Simplified Chinese resources.
- Asset JSON parses; the app icon is a 1024 × 1024 RGB PNG.
- Four original WAV sounds are valid PCM files shorter than the custom notification-sound limit.
- Python generators compile, the serve-sim script passes shell syntax validation, and `git diff --check` passes.

## Screenshots and browser delivery

Screenshots are exported from XCTest result attachments without altering the app pixels. [iPhone SE screenshots](screenshots/iphone-se/) cover English, Chinese, landscape, large text, music recovery, and actual system notification delivery. [iPhone Air screenshots](screenshots/iphone-air/) provide the same flows on the latest tested runtime. A [browser screenshot](screenshots/browser-final.jpg) records the final live mirror. Browser input successfully switched from World Clock to Timer and back to World Clock; the final preview runs the normal Chinese app, outside the UI-test defaults suite.

Representative screens: [World Clock](screenshots/iphone-air/zh-world-clock.png), [Alarm](screenshots/iphone-air/en-alarms.png), [Stopwatch](screenshots/iphone-air/en-stopwatch-laps.png), [Timer](screenshots/iphone-air/zh-timer-picker.png), and [actual background notification](screenshots/iphone-air/en-background-timer-notification.png).

The simulator mirror uses `serve-sim` scoped to the iPhone Air UDID and is opened in the Codex in-app browser at `http://localhost:3200/`. A browser click is checked against a visible app-screen change. Keep the mirror terminal alive to retain the connection.

## Limits of this verification

Downloaded, unprotected Music-library song selection and playback are implemented with public MediaPlayer APIs but have not been verified on a physical iPhone. Simulator presents a localized recovery panel because it cannot access a device's music library. Background songs fall back to the selected bundled notification tone. Background reminders obey notification permissions, Silent Mode, Focus, and system policy. `Stop Playing` can interrupt audio in the foreground; a third-party app cannot schedule control of another app's playback in the background.

The recreation targets the iPhone Clock layout. The distinct historical iPad map/weather dashboard is outside this implementation. Current keyboards, Music picker, permission prompts, and notification banners retain their OS appearance. Original artwork and chimes are used in place of copied Apple assets.

## Physical-device installation

On 11 October 2026, the user requested replacing the project's NotesSix app on their iPhone with ClockSix and explicitly selected NotesSix after the two installed Notes apps were identified. CoreDevice uninstalled `com.yinyueyang.notessix`; a subsequent exact bundle-ID query returned no installed app. Apple's `com.apple.mobilenotes` remains installed.

ClockSix 1.0 (1) was built with Xcode 27.0 for the connected physical iPhone Air running iOS 27.0.1. Automatic signing used the existing development team as a build override; no personal signing settings were added to the project. Strict code-signature verification passed, the embedded profile includes the target iPhone, and CoreDevice confirmed installation of `com.yinyueyang.clocksix`. The development profile expires on 18 October 2026 at 15:04:11 Europe/London (14:04:11 UTC); another signed installation is required after that expiry.

The first launch was rejected because the phone was locked. After the user unlocked it, a normal foreground launch succeeded with no app arguments and `startStopped: false`. An independent process query found ClockSix running as PID 1305. No debugger or UI-testing flags were used, so normal saved state and device/app language preferences apply.

Build log: `/private/tmp/clock-six-device-build.log`. Scoped install, launch, process, and uninstall verification JSON files are retained as `/private/tmp/clocksix-device-*.json` and `/private/tmp/clocksix-notessix-*.json`. This proves installation and independent startup; it does not claim a physical-device visual retest of every flow or Music-library selection. App source was unchanged during this installation, so earlier simulator suites were not repeated.
