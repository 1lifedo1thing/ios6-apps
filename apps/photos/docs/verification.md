# PhotosSix verification

Verified on 2026-10-15. This record distinguishes original interface references, simulator behavior, and physical-device evidence.

## Visual direction

The initial blue navigation and framed album covers were replaced after the user's reference correction. The accepted implementation direction is the iPhone's graphite metal navigation, black glossy controls, compact 56-point album rows with edge-aligned covers and inline counts, four-column portrait thumbnails, and persistent Albums / Photo Stream / Places tabs in Camera Roll. The Places symbol is a globe. The photographic sunflower icon uses the original generated master in `artwork/`.

The main library extends graphite through both modern safe areas; the viewer extends black; supporting settings retain pinstripes. Real system status content is used. Portrait, landscape, iPhone Air safe areas, and the compact SE were inspected. Demo imagery is labeled. System services keep their modern appearance. The [README](../README.md) records public-API and historical-service boundaries.

Representative final screenshots: [English albums](screenshots/air/english-albums.png), [English grid](screenshots/air/english-grid.png), [Chinese albums](screenshots/air/chinese-albums.png), [Chinese landscape grid](screenshots/air/chinese-landscape-grid.png), [viewer](screenshots/air/english-viewer.png), [editing](screenshots/air/photo-editor.png), [classic sharing](screenshots/air/classic-share.png), [video trimming](screenshots/air/video-trim.png), and [CameraSix capture opened in PhotosSix](screenshots/camera-capture-in-photos.png). Corresponding compact captures are in `screenshots/se/`. All repository screenshots contain simulator fixtures; personal physical-library screenshots were not saved to the repository.

## Simulator results

| Environment | Checks | Result |
| --- | --- | --- |
| iPhone Air, iOS 26.2 | 6 Photos unit tests and 4 UI workflows | 10 passed |
| iPhone SE (3rd generation), iOS 17.5 | Same unit tests and UI workflows | 10 passed |
| iPhone Air, actual simulator PhotoKit library | Create/rename album, add/remove existing asset, delete empty test album, preserve source asset count | Passed; the OS-owned deletion confirmation was handled interactively |
| iPhone Air, CameraSix + PhotosSix | Demo preview → camera capture → save to real simulator Photos → exact asset link → real library viewer → return to camera | Passed |
| iPhone Air, CameraSix | Existing unit/switch/processing checks plus index/link compatibility regression | 10 passed |

Photos unit coverage includes Chinese variants and unsupported-language fallback; persisted album operations and duplicate membership; source-preserving JPEG edits; orientation normalization for portrait metadata; actual playable MOV export and a 1.5-second trim from a four-second movie; location grouping; and persistent ordering.

UI coverage includes English album/grid/viewer, previous/next, rotate/crop/save, slideshow start/stop, sharing cancellation and return, new album with item selection, album naming cancellation, Traditional-Chinese preferences resolving to Simplified Chinese, Places/settings, landscape, video playback, and trimming. The PhotoKit integration check creates only a temporary empty album and keeps the underlying camera fixture. Its native album-deletion prompt is intentionally interactive, rather than bypassed.

The bridge test now starts PhotosSix in demo mode and confirms that an incoming CameraSix asset link switches to the actual PhotoKit library; demo identifiers disappear from the resulting grid. Both ordinary library mode and a running demo preview have been exercised.

XcodeBuildMCP result bundles from this run are retained under the host's `~/Library/Developer/XcodeBuildMCP/workspaces/ios6-apps-5274783ae1de/result-bundles/`:

- Air regular: `test_sim_2026-10-15T12-01-55-616Z_pid90370_8751d32c.xcresult`.
- SE regular: `test_sim_2026-10-15T12-06-01-008Z_pid90370_29d087c6.xcresult`.
- Camera unit regression: `test_sim_2026-10-15T12-09-35-931Z_pid90370_ab6f8a1b.xcresult`.
- Real PhotoKit album changes and bridge: `test_sim_2026-10-15T12-10-01-266Z_pid90370_8bd8f64c.xcresult`.
- Demo-to-system bridge regression: `test_sim_2026-10-15T12-17-01-550Z_pid90370_31abc054.xcresult`.

## Physical device

The connected iPhone Air runs iOS 27.0.1. Both apps were built with the repository's development team and installed with automatic signing. The user's free-profile limit was initially full; after the user explicitly selected ClockSix for removal and accepted the loss of its local data, only `com.yinyueyang.clocksix` was uninstalled. CameraSix and PhotosSix were then installed successfully.

The user unlocked iPhone Mirroring and explicitly granted PhotosSix full photo-library access. The native Chinese album list loaded the real library and existing user album names. Both app processes were independently observed through `devicectl`, without a debugger. The mirror provided visual observation; native automated clicks were unavailable, and Xcode's Device Interaction tool did not support this physical target.

A signed Debug `--device-smoke` run against the authorized real library verified actual still decoding, image editing/JPEG output, and a one-second export from a recent real video. The temporary rendered video was removed from the app's private directory; system-library originals were preserved. The aggregate [device check](device-check.json) contains pass flags only, with personal library counts removed. One older cloud-only video was unavailable during the first check; retrying a recent available video succeeded. The UI presents loading/retry states for unavailable cloud originals.

The final installed app uses the normal system library on ordinary launch. The phone initially auto-locked during the final foreground-launch attempt. After the user confirmed another unlock, the final installed PhotosSix launched successfully through `devicectl`, and its independent process was observed without a debugger. The later shared-chrome build was also signed, installed, and successfully launched. These checks do not claim human retesting of every physical touch flow, mail/message delivery, an actual AirPrint job, or AirPlay equipment. No messages were sent and no real system photos were deleted.

## Browser mirror and resources

`serve-sim` was started for the explicit Air simulator UDID with scoped cleanup and an exit trap. Its printed `http://localhost:3200` URL was opened in Codex's in-app side browser, and screenshots confirmed real frames and a live connection. The terminal remains running for the delivered preview.

`verify_resources.py` passed with 120 matching English/Simplified-Chinese keys, Chinese privacy aliases, URL schemes, an opaque 1024×1024 icon, 12 original scenes, a nonempty generated MOV, a valid project, and workspace registration. Camera's corresponding verifier passed with 94 strings. Strict `swift-format` and `git diff --check` passed. Signed builds succeeded; Xcode reported only its informational App Intents metadata warning because these apps have no App Intents dependency.

## Shared Camera Roll appearance

PhotosSix and CameraSix now compile identical navigation/button primitives from `shared/PhotoChrome/ClassicPhotoChrome.swift`. PhotosSix's existing colors and geometry were retained while Camera Roll adopted them. The shared build passed the Air browse/edit/slideshow/share workflow and the exact-asset CameraSix integration (`test_sim_2026-10-15T12-31-02-762Z_pid90370_f00aa91e.xcresult`). Camera Roll's English/Chinese, compact/wide, viewer, and editor evidence is recorded in [CameraSix verification](../../camera/docs/verification.md#matching-photossix-chrome--2026-10-15).

## Navigation button bezel correction — 2026-10-15

The shared button's straight top highlight was replaced with an inset rounded stroke, keeping the dark outer border continuous through both top corners. Original gradients, typography, dimensions, and actions were retained. [Native-resolution navigation detail](screenshots/button-bezel/navigation-after.png) and [full albums capture](screenshots/button-bezel/albums-after.png) show all three corrected buttons. Camera Roll receives the same correction from the shared source; its [before/after evidence and validation](../../camera/docs/verification.md#navigation-button-bezel-correction--2026-10-15) record the affected workflows. The SE/iOS 17.5 Chinese settings/landscape test passed; the signed physical PhotosSix update installed and launched independently. The live Air preview remains in the Codex side browser.

## Large libraries: counters and browsing position — 2026-10-15

The reported 6,625-item library exposed two defects: fixed title insets let a long Chinese ordinal overlap the back control, and replacing the grid with the viewer recreated its scroll view on return. The shared navigation now measures both button groups and reserves symmetric title space; the viewer displays compact localized `index / total` numbers while accessibility retains the complete ordinal. CameraSix uses the same adaptive layout and compact counter.

The album grid stays mounted, hidden and noninteractive beneath the viewer, preserving the exact viewport when returning from the same item. First visits to Camera Roll/Videos open near the newest items. Per-album photo identifiers and dates are saved locally for album re-entry and relaunch; demo and system positions use separate records. Viewer navigation/deletion returns near the current/next surviving item, and missing/deleted/revoked anchors resolve to the next surviving date or the last available item. A full-width lazy row is the scroll target: native iOS 17 captures showed cell-based grid restoration shifting several rows despite a valid saved identifier; row targets fixed the measured offset without changing the four/seven-column appearance.

Validation uses Debug-only `--ui-testing --large-library`: 6,625 fixture entries referencing the existing demo files, without creating any system-library assets. The Chinese workflow verifies initial latest-item visibility, scrolling into an older region, navigation/control separation, return to the same thumbnail within 3 points of its original screen coordinate, album re-entry, demo-item deletion and neighboring visibility, and preservation across process relaunch. The English workflow verifies the last-item counter, previous/next return, and rotation. Both passed on SE/iOS 17.5; the final row implementation also passed the Chinese workflow, album creation, browse/edit/slideshow/share, and the CameraSix exact-asset bridge on Air/iOS 26.2. Seven unit tests, including per-album persisted anchors, deleted-anchor fallback, empty libraries, and demo/system isolation, passed. The initial complete Air run also passed all four established UI workflows; affected workflows were rerun after the row compatibility change. CameraSix's HDR/gallery/edit/persistence/deletion workflow passed with the adaptive shared navigation.

Final result bundles in the host's XcodeBuildMCP result directory:

- Unit and initial complete Air regression (12 passed): `test_sim_2026-10-15T12-56-42-010Z_pid90370_33f0c0fa.xcresult`.
- Final SE Chinese position/deletion/relaunch: `test_sim_2026-10-15T13-08-31-029Z_pid90370_5fd028e1.xcresult`.
- Final SE English last counter/rotation: `test_sim_2026-10-15T13-09-59-648Z_pid90370_794d942c.xcresult`.
- Final CameraSix gallery regression: `test_sim_2026-10-15T13-10-19-279Z_pid90370_02e4a1a9.xcresult`.
- Final Air position, album, editing/sharing, and bridge (4 passed): `test_sim_2026-10-15T13-11-40-185Z_pid90370_5942788a.xcresult`.

Representative final evidence: [Air counter](screenshots/large-library/air/chinese-navigation-detail.png), [Air deletion return](screenshots/large-library/air/large-after-delete.png), [Air relaunch](screenshots/large-library/air/large-restored-grid.png), [SE counter](screenshots/large-library/se/chinese-navigation-detail.png), [SE re-entry](screenshots/large-library/se/large-reopened-grid.png), and [SE relaunch](screenshots/large-library/se/large-restored-grid.png). All use isolated fixtures.

Both signed device builds passed. CameraSix updated in place. Initial PhotosSix install attempts lost the device connection; after the user reconnected/unlocked the phone, the final row-based PhotosSix installed successfully and launched normally without a debugger. A later CameraSix launch attempt was blocked by auto-lock; its final installed navigation was verified in Simulator. The PhotosSix check is installation/startup evidence, not a claim of automated physical deletion testing. No real photos or albums were deleted. Resource checks passed with 121 Photos and 95 Camera bilingual keys; strict Swift formatting and whitespace checks passed.

## Neutral settings appearance — 2026-10-15

The settings surface no longer uses the obsolete blue-gray palette: its pinstripes are neutral gray, body text is charcoal, and Done uses the same black glossy button as other photo navigation controls. The existing gray metal navigation, white permission panel, and continuous light body through both safe areas remain. Real system status content stays dark for contrast.

Visual inspection also exposed an empty-slot navigation regression: settings supplies no leading control, and SwiftUI omitted that empty layout child. The shared navigation now keeps explicit leading/trailing slots even for empty content, preserving a centered Photos title and a right-aligned Done button. The existing settings workflow now asserts both positions. That workflow passed on Air/iOS 26.2 (`test_sim_2026-10-15T13-21-06-295Z_pid90370_1a39b864.xcresult`) and SE/iOS 17.5 (`test_sim_2026-10-15T13-20-39-271Z_pid90370_ba9a6a48.xcresult`), including dismissal, return to the library, and rotation. The Air large English counter/next-photo/return test passed alongside it to check nonempty navigation slots. English settings were inspected in the live side-browser preview.

Final captures: [Air Chinese](screenshots/settings-neutral/air-chinese.png), [SE Chinese](screenshots/settings-neutral/se-chinese.png), and [English preview](screenshots/settings-neutral/air-english.jpg). Resource validation, strict Swift formatting, and whitespace checks passed. The signed PhotosSix update installed in place on the physical iPhone; the subsequent foreground launch was blocked by device auto-lock. Simulator checks verify the new settings UI; physical startup of this particular update is not claimed. Existing photos, access authorization, and browsing records were retained.

## Final physical confirmation and session cleanup — 2026-10-15

After the settings update, an independent foreground-launch retry still received the OS `Locked` response. The user then directly confirmed on the iPhone that PhotosSix opened normally, the gray settings page displayed correctly, and Done returned normally. This is user-confirmed physical interaction evidence, separate from the automated simulator checks; no independent physical screenshot is claimed.

The user authorized cleanup after that confirmation. No Xcode main process was running at inspection time. The tracked `serve_sim.sh` session for Air UDID `E092AACD-B2F6-493E-8BAE-E9D7A704ABD8` was stopped using the scoped `serve-sim --kill <UDID>` path, and the tracked terminal exited successfully. The associated Codex preview tab was closed. Final inspection found no tracked mirror processes, no TCP 3200 listener, and an HTTP connection failure for the former preview URL. Other app processes and simulator data were preserved. The earlier live-preview statements above describe the delivery state before this user-requested cleanup.
