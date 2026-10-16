# MapsSix verification

Date: 16 October 2026 (Europe/London). Project: `apps/maps/MapsSix.xcodeproj`. Scheme: `MapsSix`. Bundle: `com.yinyueyang.mapssix`. Minimum deployment target: iOS 17.0.

## Single recess and clean lifted paper: Build 11

The user requested two focused refinements: remove the intermediate gray triangle inside the closed fold's dark recess, and remove the extra triangular patch on the lifted paper. The idle paper contour and live-map cutout remain unchanged; the independent gray triangle fill/path was removed, leaving the paper and one continuous dark recess.

The lifted-paper artifact came from the source texture. Build 10 temporarily cleared `map.layer.mask` inside an uncommitted Core Animation transaction, so UIKit still captured the rendered cutout. That black polygon became a second gray triangle when the Metal shader blended a faint map impression into the paper back. Merely changing `afterScreenUpdates` to `true` did not fix it. Build 11 commits and flushes the temporary unmasked layer tree before capture, captures recent updates, and restores the idle mask immediately afterward. Diagnostic source-image crops confirmed that map tiles now fill the former cutout. Temporary snapshot-dump instrumentation was removed. The Metal mesh, paper silhouette, animation duration, controls, search behavior, and localization rules were preserved.

| Check | Environment | Result |
| --- | --- | --- |
| Open/close, map styles, traffic, settings, pins; Chinese variant, landscape options, portrait return, search recovery | Air iOS 26.2 | 2 focused tests passed |
| Same flows with the older UIKit runtime and rectangular-screen fold | SE iOS 17.5 | 2 focused tests passed |
| Closed fold and lifted upper corner | Actual Air browser and native Air/SE screenshots | Extra gray triangles absent in inspected screenshots |
| Opening animation and landscape closing | Actual Air Simulator recording | Inspected; continuous paper surface and returning controls observed |
| Localization resources and strict Swift formatting | 107 bilingual keys and Swift sources | Passed |
| Signed Build 11 and signature verification | Physical iPhone Air | Passed |
| Update installation | Physical iPhone Air | Passed; installation database sequence 2856 |
| Independent launch and subsequent process query | Physical iPhone Air | Passed; PID 23520, no debugger attached |

Final results: `test_sim_2026-10-16T15-23-01-253Z_pid28276_92377295.xcresult` (Air, 2 passed) and `test_sim_2026-10-16T15-24-26-776Z_pid28276_598850ac.xcresult` (SE, 2 passed), under the local XcodeBuildMCP result-bundles directory. These checks cover the changed rendering and related transitions; they are distinct from a physical-device visual retest.

Evidence: [before/after for both reported areas](screenshots/fold-cleanup/before-after.png), [actual browser frame](screenshots/fold-cleanup/browser-closed.png), [Air open page](screenshots/fold-cleanup/air-english-page-curl.png), [SE open page](screenshots/fold-cleanup/se-english-page-curl.png), [Chinese landscape options](screenshots/fold-cleanup/air-chinese-landscape-options.png), and [actual portrait opening clip](screenshots/fold-cleanup/portrait-opening.mp4). The [before](screenshots/fold-cleanup/source-mask-before.png) and [after](screenshots/fold-cleanup/source-mask-after.png) source-texture crops document the cached-mask diagnosis; they are diagnostic images, not user-interface screenshots.

## Reference-calibrated connected paper: Build 10

The user rejected Build 9 because the fold shape and shadow still differed, the dark triangle narrowed into a curved sliver, and the display corner clipped the material. Functional success in those earlier runs does not establish visual acceptance.

The reference tip, lower point, and quadratic roll were measured from the supplied historical screenshot. In normalized reference coordinates they are `(6.5, 25.5)`, `(15, 40)`, and control `(31.66, 13.62)`, with the upper crease at `(32, 0)`. Rectangular displays retain that geometry. Rounded displays keep the complete paper tip and triangular recess vertex inside the visible area and continue the white paper along the crease to the actual map edge. The triangle remains distinct from the deeper outer recess. The lower connection curves into the bottom boundary; map pixels no longer form a tongue beneath the paper. Lighting now darkens toward the lower surface instead of maintaining a white strip throughout.

The native MKMapView now has a local even-odd paper cutout. Both that cutout and the SwiftUI material use `MapFoldGeometry`; the drawing and live-map boundary therefore move together. The full map still fills the real status/bottom regions. No device-perimeter mask or app wrapper is added. Snapshot capture attempted to remove the idle cutout, but Build 11 later proved that the uncommitted mask change remained in the captured texture. The earlier screenshot inspection missed that artifact; the Build 11 section records its correction.

| Check | Environment | Result |
| --- | --- | --- |
| Final fold: full-screen bounds, long press, styles, landscape Bookmarks, options/settings/pins | Air iOS 26.2 | 2 tests passed |
| Final fold and rectangular-screen path: same map/options flows | SE iOS 17.5 | 2 tests passed |
| Search focus, keyboard, first result, both landscape directions, cancel/return baseline, English and Chinese variant | Air iOS 26.2, after native mask integration | Passed; subsequent changes only affected idle fold geometry/material |
| Paper/triangle visibility and connection | Actual Air browser framebuffer, footer context and enlarged reference comparison | Inspected; final comparison retained |
| Open-page snapshot and landscape fold | Air/SE XCTest screenshots | Inspected |
| Localization resources and strict Swift formatting | 107 bilingual keys and Swift sources | Passed |
| Signed Build 10 and signature verification | Physical iPhone Air | Passed |
| Update installation | Physical iPhone Air | Passed, installation database sequence 2848 |
| Independent launch | Physical iPhone Air | Passed; no debugger attached |

Final Air result: `test_sim_2026-10-16T15-06-18-170Z_pid28276_89f0c340.xcresult` (2 passed). Final SE result: `test_sim_2026-10-16T15-07-38-472Z_pid28276_a0967b2a.xcresult` (2 passed). The mask/search integration run is `test_sim_2026-10-16T15-00-41-823Z_pid28276_b08faf97.xcresult` (3 passed), including bilingual search; its earlier idle contour is not the final visual evidence. Result bundles are in the local XcodeBuildMCP result-bundles directory.

Visual evidence: [original/current comparison at matched display-width scale](screenshots/reference-fold-calibration/reference-current.png), [actual browser framebuffer](screenshots/reference-fold-calibration/browser-map.png), [Air standard map](screenshots/reference-fold-calibration/air-full-screen-standard-map.png), [Air landscape](screenshots/reference-fold-calibration/air-full-screen-landscape-map.png), [Air open page](screenshots/reference-fold-calibration/air-english-page-curl.png), [SE closed map](screenshots/reference-fold-calibration/se-full-screen-standard-map.png), and [SE open page](screenshots/reference-fold-calibration/se-english-page-curl.png). Browser proof uses a controlled simulator viewport with live MapKit cartography; it does not prove physical GPS or a physical-device visual retest. This is an adaptation for rounded displays, not a claim of pixel-identical historical rendering or user visual acceptance.

## Edge-connected fold and search-control repair: Build 9

The user rejected Build 7 because its paper and dark backing were clipped by the rounded display. An intermediate Build 8 moved the complete drawing into the safe area; the user correctly rejected its floating, rectangular-patch appearance. Those versions do not establish visual acceptance.

Build 9 keeps the reference paper diagonal and curved back intact, with a small inward allowance on rounded displays. The opaque linen cutout continues the crease to the actual map edge and fills the exposed corner beneath the paper. The recess no longer ends at an inset rectangular boundary. This is a procedural composition over the live map, with no additional rounded device mask or app wrapper. The edge-bound 64-by-80-point touch region has its center above the bottom safe-area boundary. The separate location/3D group keeps its safe-area layout.

The reported search overlap had two causes: the floating controls were missing the search-state visibility condition, and the previous toolbar reapplied a bottom inset that changed with the keyboard. Search focus and results now remove both the floating group and the idle fold. The group no longer carries manual safe-area padding from the content geometry. The map background stays full-screen while search content continues to avoid the keyboard. Inactive map options are removed entirely, including the compact Done action that previously remained in the accessibility hierarchy.

Paper lighting was subsequently changed to follow cross-sections of its quadratic rolled edge. A darker turn at the edge and a softer cast/contact shadow replace the flat projected gradient; the backing grain has lower contrast. No interaction or layout changes were made in this material-only revision.

| Check | Environment | Result |
| --- | --- | --- |
| English and Chinese variant: search focus, visible keyboard, first-result selection, cancellation in both landscape directions, stable returned baseline, absent hidden controls | Air iOS 26.2 | Passed |
| Curl opening/closing, styles, settings, pin placement/removal | Air iOS 26.2 | Passed |
| Final material build: map long press, styles, full-display bounds, landscape Bookmarks, options/settings/pins | SE iOS 17.5 | 2 focused tests passed |
| Bilingual keyboard/search baseline before the edge-only revision | SE iOS 17.5 | Passed |
| Final material and physical edge | Live Air browser, full map plus enlarged crop | Inspected; screenshots retained for direct comparison |
| Resource and strict Swift formatting | 107 bilingual keys and all Swift sources | Passed |
| Final signed Build 9, signature verification and update installation | Physical iPhone Air | Passed |
| Independent launch after final update | Physical iPhone Air | Passed; no debugger attached |

The Air functional result is `test_sim_2026-10-16T13-54-31-521Z_pid28276_4a90e875.xcresult` (2 passed). The final SE build/material result is `test_sim_2026-10-16T13-59-38-742Z_pid28276_b98cbfb9.xcresult` (2 passed). SE bilingual search is in `test_sim_2026-10-16T13-43-28-179Z_pid28276_681cddd4.xcresult`. These bundles are stored under the local XcodeBuildMCP result-bundles directory. The final paint-only revision did not repeat the already passing Air interaction suite.

Visual evidence: [actual reference/current/search comparison](screenshots/edge-connected-corner/fix-proof.png), [live Air browser](screenshots/edge-connected-corner/browser-map.png), [Chinese search and keyboard](screenshots/edge-connected-corner/air-zh-Hant-TW-search-first-result.png), [English search and keyboard](screenshots/edge-connected-corner/air-en-search-first-result.png), [SE closed map](screenshots/edge-connected-corner/se-full-screen-standard-map.png), and [SE open options](screenshots/edge-connected-corner/se-english-page-curl.png). Reference and current crops are matched by their screen widths before enlargement. Functional assertions are not a claim that the historical appearance is pixel-identical or user-approved. Physical installation and launch are distinct from a visual retest of the phone's search flow.

## Reference silhouette and navigation polish: Build 7

The idle fold was compared against the user's original iOS 6 Maps crop. A rotated, flattened paper tip was rejected during iteration. The final drawing retains the reference diagonal, a sharp inward tip, a curved cool-gray paper back, and a finite linen recess with a separate contact shadow. Rounded displays enlarge the reference by 1.4 and deepen the rolled edge so its shadow remains visible inside the actual display boundary. The device supplies its own outer clipping; no app-level display mask or wrapper is added. The original-size path remains in use on the compact rectangular display.

The idle corner is an independent display-edge overlay. Its touch target is 64 points on rounded displays and at least 44 points on rectangular displays. It is absent during opening, options, closing, search, and supporting panels. The full-screen map retains touch input outside the control, and the floating location/3D group is independent of the paper drawing. Bookmarks now has a continuous silver gradient, a 13-point prompt, a centered 20-point title, and lighter text relief; the original top/bottom control arrangement is retained.

| Check | Environment | Result |
| --- | --- | --- |
| Bilingual Bookmarks/Recents/Landmarks, selected states, Clear, Done, reopen, rotation | Air iOS 26.2 and SE iOS 17.5 | Passed, 2 focused tests per device |
| Full-screen map gestures, map modes, landscape navigation, options, settings and pins | Air iOS 26.2 and SE iOS 17.5 | Passed, 2 focused tests per device |
| Final unrotated fold: Chinese variant, portrait/landscape, options close/reopen and search recovery | Air iOS 26.2 | Passed |
| Actual closed-fold inspection | Air live browser, city and ocean map backgrounds; SE screenshot | Inspected with surrounding controls and display edges |
| Localization resources and strict Swift formatting | 107 bilingual keys and Swift sources | Passed |
| Final signed Build 7, signature verification and update installation | Physical iPhone Air | Passed |
| Independent launch and subsequent process query | Physical iPhone Air | Passed; PID 23031, no debugger attached |

The final Air rotation result is `test_sim_2026-10-16T13-25-31-405Z_pid28276_f97a7825.xcresult`. Map/options runs are `test_sim_2026-10-16T13-16-49-468Z_pid28276_ba77de8e.xcresult` (Air) and `test_sim_2026-10-16T13-18-08-528Z_pid28276_d5f6fcce.xcresult` (SE). Bilingual navigation runs are `test_sim_2026-10-16T12-50-18-095Z_pid28276_687d2ebd.xcresult` (Air) and `test_sim_2026-10-16T12-52-00-031Z_pid28276_be6ba4d5.xcresult` (SE). The last silhouette revision affected only the rounded-display drawing; the compact path and polished navigation remained unchanged.

Visual evidence: [original and current footer comparison](screenshots/reference-refinement/corner-comparison.png), [final live browser](screenshots/reference-refinement/browser-live.png), [final native Air map](screenshots/reference-refinement/air-map.png), [Chinese bookmarks](screenshots/reference-refinement/air-zh-Hant-TW-bookmarks-chrome.png), [English bookmarks](screenshots/reference-refinement/air-en-bookmarks-chrome.png), [final landscape options](screenshots/reference-refinement/air-chinese-landscape-options.png), and [compact map](screenshots/reference-refinement/se-map.png). The final live browser capture is an ordinary launch awaiting a simulator location fix; it is visual proof of the fold on water, not evidence of physical GPS performance. Physical startup location was confirmed by the user earlier. No pixel-identical historical cartography or exhaustive physical-device visual retest is claimed.

## Results

| Check | Environment | Result |
| --- | --- | --- |
| Main unit and UI suite | iPhone Air, iOS 26.2 | 13 passed, 0 failed, 0 skipped |
| Main unit and UI suite | iPhone SE (3rd generation), iOS 17.5 | 13 passed, 0 failed, 0 skipped |
| Startup-location fix and complete unit suite | iPhone Air, iOS 26.2 | 10 passed, 0 failed, 0 skipped |
| Startup-location fix and complete unit suite | iPhone SE, iOS 17.5 | 10 passed, 0 failed, 0 skipped |
| Follow-up Chinese rotation/search and live Apple search/walking route | iPhone Air, iOS 26.2 | 2 passed, 0 failed, 0 skipped |
| Signed device build and signature verification | Physical iPhone Air | Passed |
| Build 2 installation | Physical iPhone Air | Passed |
| Build 2 current-location behavior | Physical iPhone Air | User confirmed automatic current-location display |
| Independent device process query | Physical iPhone Air | MapsSix running, PID 22505 after Build 2 update |
| Localization/artwork resources | 104 English and Simplified Chinese keys | Key parity, format placeholders, literal lookups, permissions, asset manifests, image integrity passed |
| Swift formatting and whitespace | All new Swift sources and Git diff | Strict lint and diff checks passed |

The main simulator suites cover bookmark creation and persistence across relaunch; map modes, traffic, real selected-unit and voice-setting changes; dropping/removing a pin; directions, route steps, navigation start/next/end/reopening; Chinese variants mapped to Simplified Chinese; landscape and portrait return; no-results recovery; real Apple place search and a real walking route.

The location-focused suite additionally covers initial permission requests, idempotent startup, authorization changes, denied permission and recovery, reduced-accuracy browsing, following multiple location samples, manual browsing stopping follow mode, freshness/accuracy validation, maneuver progression, arrival, screen-awake restoration, cancellation, and clearing a previous route when selecting a new destination.

## Full-display map background: Build 5

The live MKMapView now fills the display behind the real status bar, search/navigation chrome, home-indicator area, and landscape side insets. The same map supplies every region; there is no separate static map strip. Foreground controls retain their safe-area placement. Page-turn snapshots crop the content viewport from the full-screen map, preserving its scale and alignment. MapKit control margins include app chrome and keep attribution above the floating buttons. Standard maps use dark status text, satellite/hybrid maps use light status text, and supporting panels retain their light styling.

| Check | Environment | Result |
| --- | --- | --- |
| Full-display map bounds, actual map long press, three map modes, page opening/closing, landscape Bookmarks/Done | Air iOS 26.2 and SE iOS 17.5 | Passed on both |
| Chinese variant, landscape options, portrait return, no-results search recovery | Air iOS 26.2 and SE iOS 17.5 | Passed on both |
| Directions, route steps, navigation start/end/reopen after map reparenting | Air iOS 26.2 | Passed |
| Options, map settings, return, pin placement/removal | Air iOS 26.2 | Passed |
| Top/bottom and landscape screenshot inspection | Air and SE | Live map continuity, independent chrome, visible attribution and accessible controls observed |
| Live browser framebuffer | Air through serve-sim | Updated real map behind the status bar verified |
| Resource and strict formatting checks | 107 bilingual keys and all Swift sources | Passed |
| Final signed Build 5, signature verification, update installation | Physical iPhone Air | Passed |
| Independent launch after installation | Physical iPhone Air | Blocked by device lock; no physical UI inspection claimed |

The first full-display UI run checked landscape hit testing before rotation had settled. The test now waits for the control to become hittable and actually opens/dismisses Bookmarks after rotation; it passed on both devices. The Air navigation run emitted the previously observed test-runner priority-inversion warning; its assertions passed. Final focused result bundles are `test_sim_2026-10-16T12-31-04-881Z_pid28276_c1833708.xcresult` (Air, 2 passed) and `test_sim_2026-10-16T12-32-09-519Z_pid28276_4d864f8c.xcresult` (SE, 2 passed). The earlier Air Chinese/navigation successes are in `test_sim_2026-10-16T12-28-57-571Z_pid28276_cfe5eae3.xcresult`.

Visual proof: [live Codex browser](screenshots/map-safe-area/browser-live.png), [Air standard map](screenshots/map-safe-area/air-standard.png), [satellite status contrast](screenshots/map-safe-area/air-full-screen-Satellite-map.png), [Air landscape](screenshots/map-safe-area/air-full-screen-landscape-map.png), [portrait curl](screenshots/map-safe-area/air-english-page-curl.png), [SE standard map](screenshots/map-safe-area/se-full-screen-standard-map.png), and [SE landscape options](screenshots/map-safe-area/se-chinese-landscape-options.png).

## Navigation chrome refinement: Build 4

The Bookmarks/Recents interface was checked against [Macworld's May 2013 screenshots](https://www.macworld.com/article/221085/how-to-clear-your-apple-maps-search-history.html). The previous stacked top bars were replaced with the original arrangement: instruction and centered title above the list, a glossy blue Done button at the right, and a continuous silver segmented selector at the bottom. Its active segment uses an inset graphite surface with real selected accessibility state. Recents exposes Clear at the upper-left, disabled when empty. The existing Landmarks segment remains available in place of the historical Contacts feature. The list body is white, while details/settings retain their pinstripes. Shared supporting headers now use a 44-point bar and shaped, beveled Back buttons. Visual controls retain 44-point touch areas.

| Check | Environment | Result |
| --- | --- | --- |
| English and Chinese variant selection, titles, bottom placement, landscape, Clear, Done, reopen | iPhone Air, iOS 26.2 | Passed |
| Same bilingual navigation flow on a compact screen | iPhone SE, iOS 17.5 | Passed |
| Bookmark details, saving, persistence across relaunch | iPhone Air, iOS 26.2 | Passed |
| Shared settings header, return, options, pin placement/removal | iPhone Air, iOS 26.2 | Passed |
| Screenshot inspection | Air and SE, both languages, portrait and landscape | No clipped titles or obscured controls observed |
| Resource and strict Swift formatting checks | 107 bilingual keys and all Swift sources | Passed |
| Signed Build 4 and signature verification | Physical iPhone Air | Passed |
| Build 4 update installation | Physical iPhone Air | Passed |
| Independent launch after installation | Physical iPhone Air | Blocked by the locked device; no new physical UI inspection claimed |

Visual proof: [bilingual portrait comparison](screenshots/navigation-refinement/bilingual-preview.png), [English bookmarks](screenshots/navigation-refinement/air-en-bookmarks-chrome.png), [Chinese recents](screenshots/navigation-refinement/air-zh-Hant-TW-recents-chrome.png), [Air landscape](screenshots/navigation-refinement/air-en-bookmarks-landscape.png), [SE landscape](screenshots/navigation-refinement/se-zh-Hant-TW-bookmarks-landscape.png), [shared settings header](screenshots/navigation-refinement/air-english-settings.png).

The current focused runs passed 3 tests on Air and 1 on SE with no failures or skips. Result bundles: `test_sim_2026-10-16T12-20-34-186Z_pid28276_ee057335.xcresult` and `test_sim_2026-10-16T12-22-19-429Z_pid28276_85f565ed.xcresult`, under the local XcodeBuildMCP `result-bundles` directory. These results cover the changed navigation chrome; earlier full-suite results remain the functional baseline.

## Page curl refinement: Build 3

The user supplied original Maps screenshots as the visual target. The solid bottom toolbar was replaced with the original floating control group and an independent sharp corner. The lifted map now uses a double-sided textured Metal mesh instead of a flat shape. Opening and closing both animate continuously; the corner and control group are absent during the turn and return only after closing completes. The real map receives touch and accessibility input only while visible. Compact landscape provides a localized Done control above the scrollable options.

Current focused validation:

| Check | Environment | Result |
| --- | --- | --- |
| Options, map modes, traffic, settings, pin placement/removal | iPhone Air, iOS 26.2 | Passed |
| Chinese variant, portrait/landscape options, close and search recovery | iPhone Air, iOS 26.2 | Passed |
| Both focused UI flows | iPhone SE, iOS 17.5 | 2 passed |
| Final compact portrait fold/attribution clearance | iPhone SE, iOS 17.5 | Passed; screenshot inspected |
| Navigation start, steps, end and reopen after floating-controls change | iPhone Air, iOS 26.2 | Passed |
| Actual opening/closing recording and frame review | iPhone Air, iOS 26.2 | Continuous bend in both directions; controls return after completion |
| Reduce Motion on/off | iPhone Air, iOS 26.2 | Stable immediate opening/closing verified; original setting restored |
| Final signed Build 3 installation and independent launch | Physical iPhone Air | Passed; no debugger attached |
| Resource and formatting checks | 104 bilingual keys and all Swift sources | Passed |

Final screenshots: [closed and open](screenshots/page-curl-refinement/closed-and-open.png), [compact portrait](screenshots/page-curl-refinement/se-open.png), [Air landscape](screenshots/page-curl-refinement/air-landscape.png), [SE landscape](screenshots/page-curl-refinement/se-landscape.png), [live browser](screenshots/page-curl-refinement/browser-closed.png). The [actual page-turn recording](screenshots/page-curl-refinement/page-turn.mp4) is captured from Simulator, not an illustrative animation. No claim of pixel-identical historical map cartography or exhaustive physical-device visual testing is made.

The earlier full-suite counts and screenshots below document the functional baseline before this visual refinement. The final focused result bundles are `test_sim_2026-10-16T12-04-27-341Z_pid28276_b9f3321f.xcresult` (Air options passed), `test_sim_2026-10-16T12-05-49-306Z_pid28276_159b8f5e.xcresult` (Air rotation passed), `test_sim_2026-10-16T12-06-54-306Z_pid28276_101fc8cd.xcresult` (SE both passed), and `test_sim_2026-10-16T12-09-31-196Z_pid28276_fbacf5a9.xcresult` (final SE clearance passed), under the local XcodeBuildMCP `result-bundles` directory.

## Startup-location correction

The initial implementation opened a fixed San Francisco viewport and waited for an explicit location-button press. The user reported this on the physical device. Build 2 starts foreground location acquisition on launch, uses a world overview until a valid fix arrives, follows subsequent samples, shows locating/denied/approximate states, and accepts approximate samples for browsing. Navigation progression still requires a suitably accurate sample.

An ordinary simulator launch was checked with Core Location receiving public University of Surrey test coordinates (51.2423, -0.5906), followed by a fresh nearby sample. The map moved to Guildford and showed the blue location indicator. These are explicitly injected simulator coordinates, not evidence of physical GPS accuracy. After installation on the real iPhone, the user selected the location permission and confirmed: “已自动显示当前位置”.

## Visual proof

- [English main map](screenshots/english-map.png)
- [Physical paper fold and linen options](screenshots/english-page-curl.png)
- [Place details with saved bookmark](screenshots/english-place-details.png)
- [Route editor](screenshots/english-directions.png)
- [Green navigation sign](screenshots/english-navigation.png)
- [Simplified Chinese place bubble](screenshots/chinese-place.png)
- [Chinese landscape options](screenshots/chinese-landscape-options.png)
- [Live Apple walking route](screenshots/live-apple-walking-route.png)
- [Compact navigation](screenshots/se-english-navigation.png)
- [Compact landscape options](screenshots/se-chinese-landscape-options.png)
- [Codex browser live location preview](screenshots/browser-live.png)

The main map keeps its own layout and silver controls. Details and settings have pinstripe body material continuing behind the real status bar and bottom safe area; the Build 4 bookmarks list uses white at both ends. Landscape options use a scrollable linen surface; compact landscape rolls the map out of view so controls do not overlap it. Original procedural icon, red pushpin, and linen assets are used.

## Browser preview and interaction scope

`serve-sim` was started for iPhone Air simulator `E092AACD-B2F6-493E-8BAE-E9D7A704ABD8` and opened at `http://localhost:3200/` in the Codex side browser. A real live framebuffer, current map data, and the blue location indicator were inspected and captured. The serving terminal is retained.

The browser mirror is a canvas. Semantic interactions were verified using native XCTest and Device Hub controls. Browser pointer taps did not reliably reach the iOS 26.2 Device Hub runtime in this session, despite scoped input repair/reconnection; live streaming works. Do not treat the browser screenshot as proof of browser-pointer interaction.

## Device delivery

The first signed build was blocked by Xcode having no logged-in Apple developer account. The user logged in. Installation then reached Apple's three-app limit for free development profiles. After exact bundle identification, the user explicitly chose to uninstall only CalendarSix (`com.yinyueyang.calendarsix`); MapsSix was then installed successfully. CameraSix and PhotosSix were retained.

Build 2 was installed as an update. An automated launch was blocked while the phone was locked; the user unlocked/opened the app and confirmed current-location behavior. The independent `devicectl device info processes --search MapsSix` query then confirmed the updated executable remained running without a debugger.

No physical road-navigation session, calibrated GPS accuracy measurement, audible speech check, AirPrint hardware job, or exhaustive real-device visual review is claimed. The Xcode Device Interaction tool in this installation does not support physical devices, so its UI automation was not used as device proof.

## Artifacts and caveats

Local result bundles (temporary validation artifacts):

- `/private/tmp/maps-six-air-complete.xcresult`
- `/private/tmp/maps-six-se-complete.xcresult`
- `/private/tmp/maps-six-location-fix-tests.xcresult`
- `/private/tmp/maps-six-se-location-fix-tests.xcresult`
- `/private/tmp/maps-six-location-ui-tests.xcresult`

The Air main UI run emitted a test-runner priority-inversion warning during speech setup; it had no application compiler warnings or failed assertions. The SE suite and both location unit suites completed without warnings. Debug and signed device builds succeeded. The initial Documents-based build output inherited Finder metadata that prevented code signing; active build outputs were moved to `/private/tmp/`.

Current Apple cartography, map labels, coverage, and system-owned panels are documented in the [README](../README.md). Native sharing, AirPrint, public-transport handoff, and reporting through Apple Maps are implemented but were not exercised through an actual send, print job, or external report submission. Foreground navigation is implemented; background/lock-screen guidance uses Apple Maps.
