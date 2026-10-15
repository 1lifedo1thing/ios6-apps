# CameraSix

A native iOS 17+ recreation of the iPhone Camera interface from iOS 6. Open `CameraSix.xcodeproj`, or choose the `CameraSix` scheme in the collection's `iOS6Apps.xcworkspace`.

## Design

The reference is Apple's [iPhone User Guide for iOS 6, Camera chapter, pages 74–76](https://manualmachine.com/apple/iphoneios60/1975597-user-guide/). Camera keeps its specialized viewfinder layout under the [shared design language](../../docs/design-language.md): translucent silver flash/options/camera-switch buttons over the image, a black shaded capture rail, an inset oval metal shutter, a physical camera/video slider, blue focus rectangle, iris transition, classic ON/OFF controls, and an arrow-guided panorama strip. Landscape places the capture rail on the right. The preview preserves the photo/video aspect ratio, with black space on taller modern displays. The real status bar and home indicator remain unobstructed.

Artwork starts from original drawings. `scripts/generate_artwork.py` draws the illustrated simulator scenes and iris texture, and exports the refined icon master to an opaque 1024×1024 PNG. The icon's continuous metal bevel and corner highlights were refined with the built-in imagegen tool; its [master and exact edit prompt](artwork/icon-prompt.md) live in the repository so regeneration preserves the refinement. Historical screenshots are references only. The illustrated lake scenes are simulator fixtures, not live-camera images.

Camera switching closes eight curved graphite leaves, turns the viewfinder in perspective, then opens the iris once the new camera delivers frames. Chrome stays stationary. The leaves share exact boundaries, with fine cached grain and recessed seams rather than rotating rectangular slabs. The opening iris also prepares the material renderer before the first switch. Reference details come from a [contemporary native camera-flip observation](https://stackoverflow.com/questions/10491654/ios-sdk-how-to-cause-view-to-flip-when-switching-cameras) and a [historical iris screenshot](https://i.sstatic.net/1BFMI.jpg). The 0.22-second close, 0.42-second turn, and 0.28-second open are implementation timings, not measured original timings. See the [recorded transition](docs/screenshots/camera-switch/transition.mp4).

## Capture

- Photo: real JPEG capture through `AVCapturePhotoOutput`; front/rear camera switching; supported LED flash in Auto/On/Off modes.
- Viewfinder: tap for focus/exposure, hold for AE/AF lock, pinch for 1–5× zoom within hardware limits, optional thirds grid, and swipe right to open Camera Roll when idle.
- Video: `AVCaptureMovieFileOutput`, microphone audio, duration counter, recording indicator, supported torch, and still capture during recording. Camera switching is disabled during capture/recording.
- Hardware shutter: volume/capture events use the public `AVCaptureEventInteraction` API on iOS 17.2+. Earlier iOS 17 releases support the onscreen shutter.
- HDR: three real exposure brackets at −2/0/+2 EV, image alignment, and well-exposed-pixel fusion, with an optional normal-exposure copy. Flash is disabled in HDR mode. Unsupported hardware disables HDR.
- Panorama: Core Motion tracks a sweep of up to 120 degrees; overlapping camera frames are registered with Vision and blended into a bounded, feathered mosaic. Tap the arrow to reverse direction; tap Done to finish. Insufficient motion or failed registration reports an error instead of saving a fake panorama.
- Session work runs off the main thread. Backgrounding stops recording/capture, releases the camera/torch, and returning resumes the session. Interruptions and unavailable/denied permissions have recovery messages.

The HDR and panorama image processing is this project's own implementation using public APIs. It does not reproduce Apple's proprietary image pipeline. Panorama quality depends on steady motion, sufficient scene detail, lighting, parallax, and overlap; it is not Apple's cylindrical panorama algorithm. Rotation during an active video does not change the encoded video's orientation mid-recording.

## Camera Roll and privacy

Captured JPEGs/MOVs, thumbnails, and an atomic JSON index persist in the app's Application Support directory. Saving to Photos requests **add-only** access at the point of saving. A denied Photos permission leaves the local original available, and each item can be saved again from Camera Roll. Saving the same local item twice does not create another Photos asset.

The app-owned camera roll supports a thumbnail grid, full-screen photos, pinch zoom, previous/next/swipe navigation, video playback, original-file sharing, and AirPrint through the system share sheet. Photo edits (rotate, auto-enhance, centered 4:3 crop, revert) save a new JPEG and preserve the original. Deletion removes only the local app copy, after a clear confirmation; Photos copies are kept.

Camera Roll matches PhotosSix: graphite metal navigation, black glossy controls, a white four-column portrait grid (seven columns on wide displays), and black viewer/editor panels. Both projects compile the same [photo chrome source](../../shared/PhotoChrome/ClassicPhotoChrome.swift), including 44-point navigation and matching button typography. The roll keeps its direct Camera return and Photos link. Its graphite safe-area background switches to black in the viewer; the system owns status content.

The plus button opens Apple's privacy-preserving Photos picker for importing selected photos/videos. The app does not silently enumerate the entire system photo library. Apple manages permission dialogs, the Photos picker, video playback controls, sharing, and AirPrint. Photo editing is limited to the listed tools; red-eye retouching and video trimming from the separate historical Photos app are outside this camera recreation. Location tagging, Photo Stream/iCloud sync, and lock-screen replacement are not implemented.

## PhotosSix integration

PhotosSix reads the system Photos library, so CameraSix captures appear there when **Save to Photos** is enabled (the default). Local-only captures remain available in CameraSix until saved. The Photos button in Camera Roll opens PhotosSix; with a selected item it first saves that item if needed, then opens the exact PhotoKit asset. Saving persists an optional `photoAssetIdentifier` in the existing local index; older indexes remain readable and repeated saves still avoid duplicate assets.

PhotosSix opens the viewfinder through `camerasix://capture?returnTo=photos`; CameraSix handles that link by closing its local roll and resuming capture. The reverse link is `photossix://library?asset=<local identifier>`. A missing companion app or denied saving permission has a recovery message. PhotosSix's selected-photo permission may need to include the newly captured asset. No App Group is required.

## Language

Like WeatherSix, the app follows system/per-app preferred language. English uses `en`; all Chinese variants, including Traditional Chinese, use `zh-Hans`; other languages fall back to English. Buttons, accessibility labels/values, errors, dates, app display name, and camera/microphone/Photos permission descriptions are localized. Filenames and user-imported media are not translated.

## Simulator and testing

Simulator launches automatically use clearly labeled demo scenes. Demo capture exercises persistent JPEGs, playable generated MOVs, HDR/normal-copy UI, and panorama UI; it cannot verify a physical camera, microphone, LED, hardware shutter, or motion sweep.

```sh
python3 scripts/generate_artwork.py
python3 scripts/generate_localizations.py
python3 scripts/create_project.py
xcodebuild -project CameraSix.xcodeproj -scheme CameraSix \
  -destination 'platform=iOS Simulator,id=<UDID>' test
./scripts/serve_sim.sh <UDID>
```

Open the printed localhost URL in the Codex in-app browser. Keep the serving terminal alive. Cleanup is scoped to that simulator. A live browser frame proves streaming; XCTest provides native interaction assertions.

`--ui-testing` uses an isolated temporary camera roll and disables automatic Photos saving. `--preserve-test-roll` preserves that test roll across launches. `--demo` explicitly enables illustrated capture on a physical device; ordinary physical launches use the real camera. Tests cover localization fallback, HDR/flash/persistence, actual JPEG/MOV data, registration, focus/rotation, photo editing, gallery persistence/deletion, and recording/panorama flows. The physical-only smoke test covers real photo/video/still-during-video and background recovery.

A Debug build can run `--hardware-smoke` to exercise real rear/front photos, microphone video, still-during-video, HDR, and session restart without installing an extra XCTest runner. It writes an isolated `Documents/HardwareSmoke/report.json` and keeps test media out of the ordinary roll and Photos library.

Switching tests cover full-open/full-closed iris geometry in portrait and landscape, repeated requests, cancellation during a camera change, front/rear round trips in photo/video modes, and capture afterward. `--ui-testing --reduce-motion` exercises the same reduced-motion branch without changing the simulator's system preferences. Normal launches follow the system accessibility setting. Real-device checks also switch both ways while video is idle, then record and inspect its video/audio tracks.

For a real device, set your development team in Xcode if needed, enable Developer Mode, and grant camera/microphone access. Bundle ID: `com.yinyueyang.camerasix`. See the [verification record](docs/verification.md) for the actual tested scope and remaining hardware checks.
