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


## PhotosSix bridge verification — 2026-10-15

The local media index now preserves an optional PhotoKit asset identifier. A compatibility regression confirms that an older index without this field remains readable and that persisted identifiers round-trip through the PhotosSix URL. All 10 CameraSix unit/switch/processing tests passed on iPhone Air/iOS 26.2.

The installed simulator pair passed capture → save to the system library → open the exact asset in PhotosSix → return to the CameraSix viewfinder. The test also starts PhotosSix in demo mode and verifies its switch to the actual system library. See the [PhotosSix verification record](../../photos/docs/verification.md) and [capture screenshot](../../photos/docs/screenshots/camera-capture-in-photos.png).

The updated CameraSix was signed and installed on the physical iPhone Air/iOS 27.0.1. Earlier independent startup was verified; the PhotosSix record distinguishes device processing checks from simulator interaction coverage. No production media was deleted.

## Matching PhotosSix chrome — 2026-10-15

Camera Roll now uses the same shared SwiftUI photo chrome as PhotosSix, compiled directly from `shared/PhotoChrome/ClassicPhotoChrome.swift` in both independent projects. Its grid has graphite metal navigation, glossy black buttons, four square portrait columns (seven on wide displays), a white content surface, and graphite above and below the content. Viewer and editor navigation/toolbars use the matching black gradients and black safe areas. Video/HDR markers stay inside square thumbnails. Camera return, import, editing, local-only deletion, and the exact-asset Photos link remain available.

The English HDR/gallery/edit/save/persistence/delete workflow and Chinese video/still/panorama/landscape/return workflow passed on iPhone Air/iOS 26.2 and iPhone SE/iOS 17.5. Air also passed the existing focus/settings/empty-roll recovery workflow. The first new landscape assertion ran during rotation; waiting for the Photos button to become hittable resolved the test synchronization failure, and subsequent Air and SE checks passed. After the final thumbnail-marker correction, the Chinese workflow passed again on both devices.

PhotosSix's browse/edit/slideshow/share workflow and the capture → save → exact PhotosSix asset → CameraSix return integration passed with the shared chrome on Air. Both apps passed signed physical-device builds and were updated in place on iPhone Air/iOS 27.0.1. After the user confirmed unlock, each final app launched successfully through `devicectl`, independently of Xcode. Physical startup is verified; the redesigned roll's touch/visual flows were inspected in Simulator, rather than inferred from installation. No personal media was deleted.

Final fixture captures: [Chinese grid](screenshots/photos-style/air/roll-chinese-grid.png), [landscape](screenshots/photos-style/air/roll-chinese-landscape.png), [English viewer](screenshots/photos-style/air/roll-english-viewer.png), [editor](screenshots/photos-style/air/roll-english-editor.png), [empty roll](screenshots/photos-style/air/roll-chinese-empty.png), and [compact grid](screenshots/photos-style/se/roll-english-grid.png). The live Air roll is also available through the existing `serve-sim` side-browser session.

Result bundles are retained in the host's XcodeBuildMCP `ios6-apps-5274783ae1de/result-bundles/` directory: Air gallery/empty checks `test_sim_2026-10-15T12-26-24-141Z_pid90370_c8813a56.xcresult` (two passed; initial rotation assertion failed); Air synchronized Chinese `test_sim_2026-10-15T12-28-56-134Z_pid90370_62b71378.xcresult`; SE two workflows `test_sim_2026-10-15T12-29-26-974Z_pid90370_ae215a0b.xcresult`; Photos and bridge `test_sim_2026-10-15T12-31-02-762Z_pid90370_f00aa91e.xcresult`; final marker checks Air `test_sim_2026-10-15T12-32-37-027Z_pid90370_b42a7fae.xcresult` and SE `test_sim_2026-10-15T12-33-10-031Z_pid90370_31374ee9.xcresult`. Resource validation, strict Swift formatting, and whitespace checks passed.

## Navigation button bezel correction — 2026-10-15

Full-resolution screenshots exposed a drawing defect in the shared black buttons: a straight highlight painted over the top outer border stopped short of each rounded corner, leaving two dark discontinuities. The shared button now draws a continuous inset rounded highlight beneath the outer border. The fill, outline, and highlight share the same circular rounded shape; all strokes stay within its bounds. This applies to Camera Roll, its editor, and PhotosSix. Camera's separate silver viewfinder buttons were inspected at native resolution and retain their existing curved bevel.

Native-pixel evidence: [before](screenshots/button-bezel/camera-roll-before.png), [after](screenshots/button-bezel/camera-roll-after.png), with the full fixture captures alongside them. Air/iOS 26.2 passed the existing HDR/gallery/edit/save/persistence/deletion workflow (`test_sim_2026-10-15T12-40-49-048Z_pid90370_c4637f77.xcresult`). PhotosSix passed its Chinese settings/landscape workflow on SE/iOS 17.5 (`test_sim_2026-10-15T12-42-04-263Z_pid90370_b27c3dbe.xcresult`). Both updated signed apps installed in place and launched independently on the physical iPhone. Strict Swift formatting and resource/whitespace validation passed. Browser inspection confirmed the live PhotosSix frame.

## Adaptive photo counters — 2026-10-15

The shared photo navigation measures both side groups instead of reserving a fixed title inset. Camera Roll displays compact `index / total` counters and keeps the full localized ordinal as its accessibility label. The Air HDR/gallery/edit/save/persistence/deletion workflow passed (`test_sim_2026-10-15T13-10-19-279Z_pid90370_02e4a1a9.xcresult`), and the updated pair passed the exact-asset PhotosSix bridge. The signed CameraSix update installed in place; a later foreground recheck encountered device auto-lock. See [PhotosSix large-library validation](../../photos/docs/verification.md#large-libraries-counters-and-browsing-position--2026-10-15) for compact/large-count layout and scrolling evidence.
