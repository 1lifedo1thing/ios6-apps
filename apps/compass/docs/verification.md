# CompassSix verification

Verified on 11 October 2026 (Europe/London), using Xcode 27.0. This record distinguishes simulator UI/logic evidence from physical magnetometer evidence.

## Reference and implementation

Apple's [iOS 6 iPhone User Guide, chapter 27, page 104](https://cdsassets.apple.com/live/6GJYWVAV/user/ma1658_iphone_ios6_user_guide.pdf) supplies the primary reference: walnut wood, brass bezel, ivory dial and compass rose, red north marker, heading, coordinates, Maps shortcut, and magnetic/true-north information page. All bundled artwork is original. Modern safe areas, real status bars, larger displays, landscape layout, accessibility sizes, and system-owned dialogs are intentional adaptations.

Core Location and SwiftUI documentation were checked with Context7 and Apple documentation. Landscape interface directions are the opposite of the physical-device directions accepted by `headingOrientation`. Sensor configuration requests all heading changes and does not suppress location updates with a movement threshold.

## Automated validation

| Device/runtime | Check | Result |
| --- | --- | --- |
| iPhone Air, iOS 26.2 | Complete 15 unit + 5 UI tests | 20 passed, 0 failed, 0 skipped |
| iPhone SE (3rd generation), iOS 17.5 | Complete suite after compact-layout fixes | 20 passed, 0 failed, 0 skipped |
| iPhone Air, iOS 26.2 | Final UI regression after navigation/accessibility fixes | 5 passed, 0 failed, 0 skipped |
| iPhone Air, iOS 26.2 | Final unit regression after location-filter adjustment | 15 passed, 0 failed, 0 skipped |
| Simulator build | Final normal sensor-mode build, install, launch | Passed |
| iPhoneOS Debug build | Latest materials/icon, existing Personal Team, physical installation | Passed; see physical delivery below |
| All new Swift sources and tests | `swift-format lint --strict --recursive` | Passed |
| Scripts, asset JSON, Info.plist | Python syntax and metadata validation | Passed |
| Workspace integration and diff | Project/scheme registration and `git diff --check` | Passed |

Unit coverage includes eight directions and sector boundaries, 0°/360° interpolation, degree rounding, DMS second/minute carry, hemispheres, invalid/non-finite/stale samples, Maps URL coordinates, first-preferred-language fallback, matching localization keys and format placeholders, permission grant/revocation, magnetic heading without location, missing true north, calibration recovery, low accuracy, stale location removal, sensor stop/restart, ignored late callbacks, orientation-reference invalidation, timeouts, and preference persistence.

UI coverage includes English, Simplified Chinese and Traditional-Chinese preference mapping, unsupported-language English fallback, coordinates and bearing accessibility values, preview turning, disabled sample-data Maps action, magnetic/true-north selection, closing/reopening settings, denied location recovery, calibration help, both landscape directions, minimum 44-point control regions, bounded dial accessibility geometry, maximum accessibility text size, and north-preference restoration.

Representative results are stored in XcodeBuildMCP result bundles:

- Air full suite: `test_sim_2026-10-11T09-11-31-237Z_pid55901_00362dd5.xcresult`.
- Compact full suite: `test_sim_2026-10-11T09-19-24-012Z_pid55901_8ff7739b.xcresult`.
- Final Air UI regression: `test_sim_2026-10-11T09-21-27-581Z_pid55901_db1cdf24.xcresult`.
- Final unit regression: `test_sim_2026-10-11T09-28-04-133Z_pid55901_36c2eb46.xcresult`.

The result bundles are under the host's `~/Library/Developer/XcodeBuildMCP/workspaces/ios6-apps-5274783ae1de/result-bundles/`. Screenshot attachments were exported into this app's `docs/screenshots/`. The final sensor-filter adjustment does not change UI or the tested selection/formatting logic; normal Core Location and Maps were separately checked afterward.

## Actual normal-mode integration

A launch without `--demo` or `--uitesting` displayed unavailable compass hardware instead of a fabricated bearing. The Chinese system permission prompt displayed the localized Home Screen name and location explanation. Foreground location authorization was granted only in Simulator.

The reference coordinates `37.321944, -122.028056` were delivered through `simctl location` and the actual `CLLocationManagerDelegate` callback. Debug output confirmed `CompassSix current location received; coordinate values omitted`. The live interface displayed `37°19′19″ N, 122°1′41″ W` with localized hemisphere labels. The active Maps button opened Apple Maps, whose location card showed approximately `37.32194, -122.02806`. Maps' own location permission was declined; the coordinate pin still opened correctly. The source coordinates are public historical-reference sample data, not the user's physical location.

See [live location](screenshots/browser-live-location.jpg), [Chinese location permission](screenshots/browser-location-permission.jpg), and [Maps handoff](screenshots/browser-maps-handoff.jpg). The marker label follows the application's Chinese localization. Simulator cannot provide or validate real magnetic/true-north sensor readings.

## Visual evidence

- [English portrait](screenshots/en-portrait.png) and [Chinese portrait](screenshots/zh-portrait.png).
- [Chinese landscape left](screenshots/zh-landscape-left.png) and [right](screenshots/zh-landscape-right.png).
- [English settings](screenshots/en-settings.png) and [Chinese landscape settings](screenshots/zh-landscape-settings.png).
- [Denied location/true north](screenshots/zh-denied-true-north.png) and [calibration state](screenshots/en-calibration.png).
- [Large-text settings](screenshots/fallback-large-text-settings.png) and [compact large-text settings](screenshots/compact-fallback-large-text-settings.png).
- [Compact portrait](screenshots/compact-zh-portrait.png) and [compact landscape](screenshots/compact-zh-landscape-left.png).
- [Final Codex browser mirror](screenshots/browser-final.jpg).

Visual review corrected insufficient button hit regions, rotated drawing bounds leaking into the accessibility frame on iOS 17, transient preview unavailability on initial orientation, and large text clipping the navigation title/Done button. Navigation chrome has stable readable sizing while settings content scales and scrolls. Dial decoration uses fixed drawing typography with separate localized bearing accessibility semantics.

## Browser mirror

`serve-sim` was started for iPhone Air UDID `E092AACD-B2F6-493E-8BAE-E9D7A704ABD8` and opened at `http://localhost:3200/` in Codex's in-app side browser. A real live frame was inspected. Input repair, a scoped simulator restart, and mirror reconnection were used after an Xcode 27 bridge interruption. Browser clicks were subsequently verified by opening/closing settings, completing the Maps handoff, and turning the preview from 222° to 237° and back. See the [turned preview](screenshots/browser-preview-turned.jpg). The mirror remains running as requested; its script exit trap cleans up only this simulator's helper.

The final page is an explicitly labeled Simulator Preview, with sample 222° heading and historical-reference sample coordinates. The sample can be rotated using the preview controls. This is visual/interaction evidence, not physical compass accuracy evidence.

## Initial physical-device boundary

At the initial verification stage, the signed iPhoneOS app was available at `/private/tmp/compass-six-device/Build/Products/Debug-iphoneos/CompassSix.app`. An installation attempt on the connected iPhone Air was rejected with `ApplicationVerificationFailed`: the free developer profile already has WeatherSix, NotesSix, and CalculatorSix installed. No existing phone app or app data was removed.

The user initially selected completing simulator validation and deferring physical installation. At that stage, the real-device launch, magnetometer callbacks, full-turn comparison with Apple's Compass, calibration under local magnetic interference, real GPS/true north, physical orientation checks, and post-detachment runtime were unverified. This initial boundary was superseded by the physical delivery recorded below. Signed build success and simulator fixtures do not establish real-world directional accuracy.

## Build environment

The first build's app bundle inherited Finder/file-provider metadata in repository-local DerivedData and failed code signing. Building under `/private/tmp/compass-six-derived-data` resolved it. The final build logs have no source compilation errors; Xcode's expected App Intents metadata extraction warning occurs because this application has no App Intents dependency.

## Material refinement — 2026-10-11

The main screen now uses a newly authored natural walnut bitmap, with irregular grain, pores, and restrained satin shading. The same background continues behind the status area and below the toolbar through the bottom safe area. The toolbar's former bottom-safe-area extension was removed. Its controls remain in the safe area.

The brass case now has directional reflections, rounded radial bevel shading, concentric machining lines, an inset glass lip, and close contact shadows. The ivory surface has deterministic microtexture; the glass reflection and metal case remain stationary while the localized compass card rotates. The rose has shaded facets and a raised brass pivot. Landscape leaves enough space above the case to display the fixed direction marker in full. No sensor, permission, or language-selection logic changed.

The built-in image generation tool produced the committed [walnut source and prompt](../artwork/README.md). Packaging and icon regeneration use that source without a network call. The source and bundled walnut are byte-identical, with SHA-256 `3b900e3b72d0208d74f3670c376c119c5f8284b8f5c4ff48116e99a70e24c0b3`. The source is RGB 1024 × 1536; the icon is RGB 1024 × 1024. PNG decoding, asset-catalog references, Python syntax, shell syntax, strict Swift-format lint, and whitespace checks passed.

Validation for this refinement:

- iPhone Air / iOS 26.2: the complete 20-test suite passed, with zero failures or skips. Result: `test_sim_2026-10-11T09-39-32-706Z_pid55901_57406ccf.xcresult`.
- iPhone SE (3rd generation) / iOS 17.5: three affected UI tests passed, covering English preview/rotation/settings return and reopen, Chinese variants in both landscape directions and control geometry, and fallback language with large text and persistent settings. Result: `test_sim_2026-10-11T09-40-58-628Z_pid55901_314ebd51.xcresult`.
- After the final landscape spacing adjustment, the Chinese portrait/both-landscape/control-geometry test passed again on iPhone SE. Result: `test_sim_2026-10-11T09-41-49-860Z_pid55901_113116f5.xcresult`.
- The same final geometry test passed on iPhone Air. Result: `test_sim_2026-10-11T09-44-24-948Z_pid55901_1d5fb030.xcresult`. An intervening run reported a nominal 44-point accessibility frame width as `43.999999999999886`. The assertion now allows only one millionth of a point of floating-point tolerance; the actual minimum interaction size remains 44 points.

The result bundles are under `~/Library/Developer/XcodeBuildMCP/workspaces/ios6-apps-5274783ae1de/result-bundles/`. Representative full-resolution screenshots are preserved under [material-refinement](screenshots/material-refinement/): [Chinese portrait](screenshots/material-refinement/zh-portrait.png), [English portrait](screenshots/material-refinement/en-portrait.png), [Chinese landscape](screenshots/material-refinement/zh-landscape-left.png), [compact English portrait](screenshots/material-refinement/compact-en-portrait.png), and [compact Chinese landscape](screenshots/material-refinement/compact-zh-landscape-left.png). These captures were inspected for texture quality, legibility, safe-area continuity, and clipping. Existing captures outside this directory document the earlier implementation.

At this refinement stage, physical installation was deferred at the user's request. This visual refinement was verified in Simulator; the device artifact had not yet been rebuilt. The physical delivery below includes this refinement.

The existing Codex side-browser mirror was reconnected at `http://localhost:3200/`. After UI testing, live frames remained healthy but input stopped responding. The scoped `serve-sim repair-input -d E092AACD-B2F6-493E-8BAE-E9D7A704ABD8` command and mirror restart restored input. Browser clicks then visibly changed the bearing from 222° to 237° and back, opened the settings page, and returned to the compass. See the [turned preview](screenshots/material-refinement/browser-preview-turned.jpg) and [final live browser frame](screenshots/material-refinement/browser-final.jpg). The terminal remains running and the browser tab is retained as the deliverable.

## App icon redesign — 2026-10-11

The app icon was redrawn using the 2009–2013 icon in [Basic Apple Guy's historical comparison](https://basicappleguy.com/basicappleblog/ios-icon-history) and the icon in Apple's iOS 6 guide as layout references. The previous icon had an oversized yellow bezel, a flat pivot, sparse detail, and a north N obscured by its red triangle. The replacement has polished walnut, curved upper gloss, an ivory calibration band, a slender faceted rose, a dimensional brass pivot, and a visible white N.

The initial redraw incorrectly treated the outer edge as a wide silver metal case. After the user's correction, that case was removed. The selected icon uses a thin charcoal-black circular perimeter, with the pale calibration band extended outward directly inside it. All discarded silver-case drafts remain outside the app; only the final dark-perimeter source is packaged. The degree labels use twelve correct thirty-degree values around the fine tick ring for small-icon clarity; this is a newly rendered adaptation rather than a pixel-identical historical asset. The live compass dial and sensor logic are unchanged.

The original generated source is RGB 1254 × 1254, committed as [compass-icon-source.png](../artwork/compass-icon-source.png). Packaging exports an opaque RGB 1024 × 1024 app icon with no pre-applied rounded-square mask. The system applies the Home Screen mask. Built-in image generation prompts and reference provenance are preserved in the [artwork README](../artwork/README.md).

Validation:

- The independent CompassSix project built and launched on iPhone Air / iOS 26.2 without warnings or errors reported by XcodeBuildMCP. Final build log: `build_run_sim_2026-10-11T10-06-37-210Z_pid55901_abf8ed56.log` in the task's existing build-log directory.
- PNG decoding, opaque RGB format, 1024 × 1024 catalog dimensions, catalog filename references, Python syntax, and whitespace checks passed. A second resource-generation run produced byte-identical output and preserved the walnut source. Final icon SHA-256: `c86393a77d9d29bff951695cc8ec3c071966528641e28cebf09f3862753c9434`.
- The updated icon was inspected at its actual Home Screen size in the live Codex browser mirror. Clicking the icon opened the working Chinese compass preview. See the [native Home Screen capture](screenshots/icon-redesign/home-screen.png) and [browser Home Screen capture](screenshots/icon-redesign/browser-home-screen.jpg).

This change affects artwork, resource packaging, and documentation only. Sensor/unit/UI regressions were not repeated for the icon-only change. At this icon refinement stage, physical installation was deferred and the device artifact had not yet been rebuilt. The physical delivery below includes this icon.


## Physical delivery and verification — 2026-10-11

The user explicitly authorized deleting the previously installed WeatherSix app and installing the latest CompassSix on their iPhone. Device discovery confirmed the physical iPhone Air (iPhone18,4), iOS 27.0.1, a wired connection, pairing, and enabled Developer Mode.

### Build and installation

- Built the current source and asset catalog for the registered physical phone with Xcode 27.0, `Debug`, automatic provisioning, and derived data under `/private/tmp/compass-six-device`. Build log: `/private/tmp/compass-six-device-build-latest.log`, ending in `BUILD SUCCEEDED`.
- Verified the signed bundle with `codesign --verify --deep --strict`. The provisioning profile contains the target device and expires on 18 October 2026 at 10:05:04 Europe/London.
- Confirmed WeatherSix (`com.yinyueyang.weathersix`) was present, then removed only that app using `devicectl device uninstall app`. Its local phone data was removed as authorized; the project on the computer remains.
- Installed `/private/tmp/compass-six-device/Build/Products/Debug-iphoneos/CompassSix.app`. A subsequent installed-app listing contains CompassSix, NotesSix, CalculatorSix, and the pre-existing DOVE app; WeatherSix is absent.
- Fetched the actual installed icon from the phone without allowing placeholders. Its 1024 x 1024 image shows the latest thin black perimeter, ivory scale, walnut background, faceted rose, and glass highlight: [installed device icon](screenshots/device-installed-icon.png).

### Actual sensor and user verification

The app was launched in normal mode without preview, test fixtures, language overrides, or simulated location. The console reported a real hardware-heading callback and a current-location callback. The first heading callback had reported accuracy 46.739 degrees and no true heading yet; the interface correctly showed low-accuracy guidance while still displaying magnetic heading. The first device screenshot showed a Chinese heading, a correspondingly rotated dial, current coordinates, and walnut extending below the toolbar.

The user then performed the requested physical checks and reported:

- After placing the phone flat away from magnets/metal, turning it, and comparing with Apple's Compass using the same north reference: “挺准的” (reasonably accurate).
- When asked whether true north, both landscape directions, and returning from the Home Screen caused blanks, hangs, or obviously incorrect directions: “没有” (none).

An independent read of this app's preferences confirms `northReference` changed from `magnetic` to `trueNorth` and remained `trueNorth` after the independent normal-mode restart. These are real-device smoke checks with explicit human observations. No numerical error bound was measured, and no controlled magnetic-interference test or denied-permission device test was performed. Existing simulator tests cover those software states; they are not physical calibration measurements.

### Independent runtime and evidence limits

The console-connected launch was ended by replacing that app instance with a normal `devicectl device process launch --terminate-existing` launch without `--console`, test arguments, or debugger attachment. A separate device process query confirmed CompassSix running with PID 1068. The console session exited, confirming it was no longer holding the app. A second independent process query about one minute later found the same PID still running. Subsequent screen captures did not show CompassSix after the foreground app changed and are excluded from UI evidence; process existence establishes continued runtime, including in the background, rather than a second foreground UI verification.

The available Xcode Device Interaction bridge rejected the physical device (its supported list is simulators only), so device UI automation was not claimed. The installed `devicectl` supports physical screenshots; screen recording reported that the phone lacks that capability. Native device screenshots containing the user's coordinates are retained only under `/private/tmp`, not committed to this repository. Console receipt messages omit coordinate values. Installation, app-list, launch, and process JSON evidence are also under `/private/tmp/compass-*`.

This delivery changed documentation and added the fetched installed-icon evidence; no application source, sensor configuration, or UI behavior changed after the already-passing simulator regressions. No additional unit/UI regression run was needed for this device installation.
