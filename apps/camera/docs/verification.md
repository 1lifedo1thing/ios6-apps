# CameraSix verification

Date: 2026-10-14 (Europe/London). Project: `apps/camera/CameraSix.xcodeproj`. Scheme: `CameraSix`. Bundle: `com.yinyueyang.camerasix`. Minimum deployment target: iOS 17.0.

## Automated simulator evidence

| Destination | Result | Coverage |
| --- | --- | --- |
| iPhone Air, iOS 26.2 | 9 passed, 0 failed, 1 skipped | Six unit tests and three native UI workflows |
| iPhone SE (3rd generation), iOS 17.5 | 9 passed, 0 failed, 1 skipped | Same compact-device suite |
| Final localization/processing unit run, Air | 6 passed, 0 failed, 0 skipped | Includes native Traditional Chinese privacy-language fallback |
| Final focused UI run, Air | 1 passed, 0 failed, 0 skipped | Focus/pinch/rotation/settings/background recovery and right-swipe Camera Roll navigation |

The skipped test requires a physical camera/microphone. Physical verification below uses an in-app Debug-only check so the user's three free-provisioned app slots do not need an additional XCTest runner.

Assertions cover English/Chinese variants and unsupported-language fallback; HDR/flash exclusion; settings corruption fallback and persistence; local-media reload/deletion; actual JPEG exposure fusion; measured registration of overlapping frames and single-frame rejection; generated MOV duration/video-track validity; HDR and normal-copy gallery flow; photo rotation/crop saved as a separate copy; gallery persistence after process restart; delete cancellation and confirmation; Chinese video recording/still snapshot/panorama direction and saved count; focus lock/unlock; pinch zoom; camera switching; both landscape directions; settings dismissal; and background/foreground UI recovery.

Result bundles are retained by XcodeBuildMCP under `~/Library/Developer/XcodeBuildMCP/workspaces/ios6-apps-5274783ae1de/result-bundles/`:

- SE: `test_sim_2026-10-14T11-39-46-654Z_pid61929_f72aeeaf.xcresult`.
- Air (including pinch/background assertions): `test_sim_2026-10-14T11-47-27-817Z_pid61929_71951d6a.xcresult`.
- Final unit/localization run: `test_sim_2026-10-14T12-02-39-054Z_pid61929_d081fce6.xcresult`.
- Right-swipe/focus UI run: `test_sim_2026-10-14T11-57-49-126Z_pid61929_bff4857e.xcresult`.

`scripts/verify_resources.py` passes: 92 matching English/Simplified Chinese strings; placeholder parity; native `zh`/`zh-Hant` privacy aliases; original opaque 1024×1024 icon; image validity; shared scheme and workspace registration. Strict `swift-format` lint and `git diff --check` pass. Simulator build/run completes without source warnings or errors.

## Physical evidence

Device: iPhone Air (`iPhone18,4`), iOS 27.0.1. Signed Debug build and strict signature verification passed. Installation initially hit the free-profile three-app cap. At the user's explicit request, only the recreated Compass (`com.yinyueyang.compasssix`) was removed; Calendar and Clock were retained. Camera installation subsequently succeeded.

An independent `--hardware-smoke` run on the real camera produced this report between 11:42:20 and 11:42:41 UTC:

| Check | Observed evidence |
| --- | --- |
| Rear photo | Real 4032×3024 JPEG, successfully decoded |
| Video | 3.3-second MOV with HEVC 1920×1080 video and AAC audio tracks |
| Still during video | Real 1920×1080 JPEG while recording |
| Front camera | Separate real front-camera JPEG |
| HDR | Three bracketed exposures fused to a 2048×1536 JPEG; full-resolution normal copy retained |
| Session recovery | Session stopped/restarted, then another real JPEG captured |
| Real panorama | User performed a hand-held sweep; generated 1574×906 JPEG decoded successfully with nonzero pixel variance |
| Photos saving | The real panorama's `savedToPhotos` flag is true after PhotoKit's successful save completion; user also confirmed saving |

The report was read back from the app's data container. The seven captured items were copied to temporary storage and checked independently with Pillow and ffprobe: JPEGs decode with nonzero pixel variance, and the MOV includes actual video/audio streams. This is stronger evidence than installation or a running PID alone. Private camera images and recordings are not bundled into the repository or screenshots.

The first run failed to record immediately after first-time permission handling. The subsequent run passed. Lifecycle handling was adjusted to suspend only on backgrounding, allowing expected permission dialogs to be inactive without stopping the camera. This reduces an identified timing risk; the first failure's precise AVFoundation error was not retained, so it is not claimed as a proven root cause.

The Debug-only smoke check uses its own `Documents/HardwareSmoke` media folder, disables automatic Photos saving, and does not persist its settings. Ordinary launches use the normal local camera roll and production settings.

The final signed app was installed and launched in ordinary mode independently of Xcode. A separate device process query found `CameraSix` running. A separate installed-app query confirmed the recreated Compass was absent. The real panorama remains in the ordinary app camera roll; updates preserve that data.

## Visual and browser evidence

The main viewfinder follows the Camera-specific historical structure rather than the Notes/settings frame. Top flash/options/switch pills, metallic oval shutter, shaded black capture rail and recessed mode slider are present. The viewfinder respects capture aspect ratio, with intentional black space on taller displays. Settings use continuous light pinstripes behind the real status area and bottom safe area, with an independent blue-gray navigation panel.

- [Air portrait](screenshots/iphone-air/zh-photo.png), [Air settings](screenshots/iphone-air/zh-settings.png), [Air left landscape](screenshots/iphone-air/zh-landscape-left.png), [Air right landscape](screenshots/iphone-air/zh-landscape-right.png).
- [SE portrait](screenshots/iphone-se/zh-photo.png), [SE settings](screenshots/iphone-se/zh-settings.png), [SE left landscape](screenshots/iphone-se/zh-landscape-left.png), [SE right landscape](screenshots/iphone-se/zh-landscape-right.png).
- [Codex browser live stream](screenshots/browser-live.png): the serve-sim page displayed `live` and a real simulator frame. A browser-coordinate shutter tap changed the empty thumbnail to the new capture, verifying input as well as streaming. Native XCTest assertions provide separate semantic interaction evidence.

The mirror is kept running by `scripts/serve_sim.sh`, scoped to the Air simulator, at `http://localhost:3200/`. The Codex tab is retained as a deliverable. Simulator imagery is explicitly labeled as an illustrated demo; it is not presented as a physical camera feed.

## Camera-switch refinement

The original implementation switched inputs before covering the old preview, jumped directly to a six-rectangle closed mask, and hid the mask during opening. The replacement uses eight curved, shared-boundary leaves, cached graphite micro-grain, contact shadows and a perspective flip. The top controls and capture rail stay stationary. Closing takes 0.22 seconds, the turn 0.42 seconds, and opening 0.28 seconds; these are tuned implementation timings, not measured Apple timings.

Input replacement starts only after the iris closes. Three incoming video frames confirm the replacement stream before revealing it; the iris also waits for the perspective turn to complete. Idle video switching temporarily probes frames and restores the movie output. A three-second stream timeout returns control with a localized error. Repeated switches and capture/focus actions are excluded while switching. Generation tokens prevent stale animation completions from advancing a later transition after backgrounding. Reduce Motion skips the mechanical motion. The initial opening iris warms the material renderer before the first switch.

| Destination | Focused result |
| --- | --- |
| Air, iOS 26.2 | Three geometry/state/render tests and two native UI workflows passed in separate focused runs |
| SE, iOS 17.5 | Four focused tests passed: geometry/state/render and photo/video round trips with both motion branches |
| Physical iPhone Air, iOS 27.0.1 | Real photo/video front/rear switching, capture afterward, video/audio tracks, still-during-video, HDR, cancellation during input replacement and session recovery passed |

The native UI checks assert the new camera value and enabled controls, capture photos after switching, switch twice in idle video mode, record a playable movie, and assert switching is disabled while recording. The Debug-only Reduce Motion fixture exercises the production branch without changing system settings. Unit checks also cancel during input replacement and reject repeated requests. Final resource/lint/diff checks pass.

Focused result bundles:

- Final Air geometry/state/render: `test_sim_2026-10-14T12-41-48-154Z_pid61929_56700231.xcresult`.
- Air photo/video/reduced-motion workflow: `test_sim_2026-10-14T12-37-59-523Z_pid61929_fb42e8ed.xcresult`.
- Air focus/rotation workflow: `test_sim_2026-10-14T12-36-10-595Z_pid61929_edb55941.xcresult` (that workflow passed; the separate round-trip test had an English selector mismatch fixed and rerun above).
- SE focused suite: `test_sim_2026-10-14T12-39-32-632Z_pid61929_af068642.xcresult`.

The [final physical report](hardware-switch-report.json), read from the device, ran at 13:00:03–13:00:39 UTC (14:00:03–14:00:39 Europe/London). It records a 3024×4032 rear JPEG, real front JPEG, restored movie output after video-mode camera switches, and a 3.198-second movie containing one video and one audio track. It also cancels switching during input replacement, resumes the session, confirms the iris state is idle, and subsequently captures another real photo after a separate stop/start. Test media remains isolated from the normal roll and Photos. This run includes the final material refinement, suspended-session readiness guard, and updated icon. The earlier lock-screen rejection was resolved after the user unlocked the iPhone.

After the check, the app was relaunched without diagnostic arguments. A separate device-process query confirmed the ordinary CameraSix process running from the final installed bundle. The ordinary camera-roll index still contains the user's panorama with `savedToPhotos` true. No debugger is attached.

[Native transition video](screenshots/camera-switch/transition.mp4), [animated preview](screenshots/camera-switch/preview.gif), and [phase sheet](screenshots/camera-switch/phases.png) show the first switch after a fresh launch of the final build. The recorded intermediate closing, turn and opening frames were visually inspected. The browser's [updated live frame](screenshots/camera-switch/browser-live.png) remains at `http://localhost:3200/`.

## App icon corner refinement

The old procedural icon had a thin inset rounded-rectangle outline and separate horizontal light/dark bars. System corner clipping interrupted that frame. The updated metal enclosure has continuous corner shoulders, upper-left reflected highlights, subtle brushed grain and a recessed lower-right edge. The central lens composition remains recognizable. The source was edited with the built-in imagegen tool; the [exact prompt and master location](../artwork/icon-prompt.md) are retained. The export script reads that master instead of redrawing the old perimeter.

The source master is 1254×1254 opaque RGB. The consumed AppIcon is 1024×1024 opaque RGB PNG, resampled with Lanczos. Resource verification passes for image validity, icon dimensions/mode, localization and workspace registration. Simulator build/install/run succeeded without source warnings or errors. The icon was inspected on the actual iPhone Air Home Screen after installation, including the system-applied outer corners. This asset-only change does not alter capture logic or permissions.

- [Browser Home Screen proof](screenshots/app-icon/browser-home.png).
- [Native Simulator Home Screen](screenshots/app-icon/simulator-home.jpg).
- [Original source icon](screenshots/app-icon/before.png) and [refined icon](../CameraSix/Assets.xcassets/AppIcon.appiconset/AppIcon.png).

Signed device build and strict signature verification passed. The updated icon was installed over the existing CameraSix app; original camera data was retained. Physical Home Screen appearance has not been independently captured. The final-launch/cancellation check passed after device unlock; CameraSix was then launched in ordinary mode independently of Xcode.

## Scope and remaining manual checks

The HDR and panorama engines use public APIs and original processing, not Apple's private algorithms. Image registration/fusion and panorama UI are tested, and a real hand-held sweep and Photos save were verified. LED brightness/torch, physical volume-button shutter, AirPrint output, and comprehensive photo-quality assessment still require manual hardware checks and are not inferred from simulator success or the capture files. Camera Roll contains app captures and selected Photos imports; it does not silently enumerate all system photos. Separate historical Photos tools such as video trimming/red-eye editing, geotagging, Photo Stream, and system lock-screen replacement are outside the implemented scope.
