# PhotosSix

A native iOS 17+ recreation of the iPhone Photos app from iOS 6. Open `PhotosSix.xcodeproj`, or select `PhotosSix` in the collection's `iOS6Apps.xcworkspace`.

## Design and references

The visual reference is the iPhone app, not iPhoto or the iPad album bookshelf. It uses graphite metal navigation, embossed white titles, glossy black buttons, compact white album rows, inline parenthesized counts, four-column portrait thumbnails, a black image viewer, and the Albums / Photo Stream / Places tab bar. Camera Roll retains those three tabs. The sunflower icon uses an original generated photographic master; the demo images are original illustrations. Historical screenshots are not bundled.

The supporting settings page uses neutral gray pinstripes, charcoal text, a white permission panel, and black glossy controls beneath the same gray metal navigation. Its body continues through both safe areas, with dark system status content for contrast.

References: Apple's [iOS 6 iPhone User Guide, Photos pages 70–73 and Camera editing page 76](https://manualmachine.com/apple/iphoneios60/1975597-user-guide/), a [contemporary iOS 6 Camera Roll capture](https://www.foxnews.com/tech/how-to-share-photo-streams-via-the-web-using-ios-6), and a [contemporary album-list capture](https://guides.brit.co/guides/make-a-new-photo-album-for-your-iphone-44s). The user's referenced chat supplied the gray-metal direction; actual historical captures were also checked.

Under the [shared design language](../../docs/design-language.md), Photos keeps its specialized graphite frame and white library surfaces. Graphite continues behind the real status bar and home indicator, while the viewer uses black at both ends. Supporting settings use the collection's pinstripes. Controls respect modern safe areas, including landscape. No outer device mask is drawn inside the app. App-owned dialogs, sharing tiles, slideshow switches, and editing controls remain dimensional. System permission dialogs, Mail/Messages composition, print UI, video controls, and the extended share sheet retain the current OS appearance.

## Library and privacy

Normal launches read the **system photo library**, including accessible photos, videos, custom/synced albums, saved geographic locations, and available iCloud Shared Albums. No sample media is inserted into the real library. PhotoKit change observation and foreground refresh keep the contents current after captures or changes in another app.

The first access requests read/write Photos authorization. Full, selected-photo, denied, restricted, and not-yet-requested states are handled. Selected-photo access displays an explicit management control; Settings provides recovery after denial. Hidden and Recently Deleted contents are not separately exposed. iCloud media loads on demand with loading and recoverable error states; a network connection and an available cloud original may be necessary.

Create, rename, reorder, and delete editable albums; add selected items; remove items from an album without deleting their originals. Deleting from Camera Roll deletes from the system library and synced devices, after the app's explicit confirmation and any required system confirmation. Deleting an album keeps its photos. The operating system controls Recently Deleted recovery.

Album ordering is an app-local preference because PhotoKit does not offer arbitrary global reordering of the top-level system album list. User-written album names stay unchanged across language changes.

## Browsing, editing, and sharing

- Four columns in portrait, more columns when the available width exceeds 600 points; lazy thumbnails and bounded image requests.
- Camera Roll and Videos start at the newest items on their first visit. Each album remembers its position across returning from a photo, leaving the album, backgrounding, and relaunch. Deleting the viewed item returns near its next surviving neighbor; an unavailable saved anchor resolves to a nearby surviving date. Position records stay local and are separate for demo and system libraries.
- Viewer counters use compact localized numbers such as `15 / 6,625`, with the full spoken ordinal retained for accessibility. Navigation measures both button groups and reserves space around the centered title, including on compact screens.
- Full-screen still viewing, double-tap/pinch zoom, panning, swiping, accessible previous/next buttons, and date/dimension information.
- Native video playback and its supported routing controls. Still images in a mixed-media album play as a slideshow, with interval, shuffle, repeat, crossfade, and Reduce Motion support. Tap to stop; backgrounding ends slideshow playback.
- Photo rotation, automatic enhancement, targeted red-eye correction, repositionable square/4:3/3:4/16:9 crop, and reverting the current editing session. Orientation metadata is normalized before editing.
- Video start/end trimming with preview and an actual exported movie.
- Edits and trims save **new copies** to Photos and preserve the source. Photo editing uses a bounded working image of up to approximately 4096 pixels rather than a RAW editor. Metadata such as the original capture location is retained in the original asset; the new rendered copy is a separate asset. Live Photos remain viewable as stills; editing creates a still JPEG copy.
- A classic sharing panel opens configured Mail or Messages composers, copies images/URLs, prints still photos through AirPrint, and offers the system share sheet for additional destinations. The user controls recipients and sending. Unavailable services show recovery messages. Large mail attachments are directed to the extended share sheet.
- Wallpaper has instructions for the modern system Settings flow. Public APIs do not let a third-party app silently set wallpaper. System sharing may offer contact-photo assignment depending on the media and OS.

## CameraSix integration

PhotosSix and CameraSix's local roll compile the same [photo chrome source](../../shared/PhotoChrome/ClassicPhotoChrome.swift): graphite navigation, glossy buttons, black viewer/editor chrome, and matching interaction dimensions. Keep the repository's `shared/` directory alongside `apps/` when opening either project separately.

Both apps use the same system Photos library. Ordinary CameraSix capture already enables **Save to Photos** by default. Captures saved there appear in PhotosSix; local-only captures stay in CameraSix until saved.

PhotosSix's camera button opens `camerasix://capture?returnTo=photos`. CameraSix's roll has a Photos button: when a local item is selected, it saves that item if necessary and opens `photossix://library?asset=<PhotoKit local identifier>`. PhotosSix refreshes the library and opens that exact asset. An incoming CameraSix library link switches an active demo preview to the real system library, requesting Photos authorization when needed. With selected-photo authorization, the user may need to include that asset in the authorized selection. If the companion app is missing, the interface explains how to recover. No shared-container entitlement or private API is required.

CameraSix's existing local JSON index remains compatible. New saves persist the optional system asset identifier so links survive relaunch, and repeated saves retain the existing duplicate-prevention behavior.

## Language

The WeatherSix rule is preserved: the first system or per-app preferred language selects English or Simplified Chinese; all Chinese variants use Simplified Chinese; unsupported languages fall back to English. Visible labels, accessibility, dates/counts, errors, privacy descriptions, and Home Screen names are localized. The native system services may follow the device language independently.

## Demo, build, and validation

`--demo` opens an isolated illustrated library; normal Simulator and physical launches use real PhotoKit. `--ui-testing` uses a separate resettable demo index. `--preserve-demo` preserves that test index across launches. These modes never seed the system library.

Debug `--ui-testing --large-library` creates 6,625 in-memory fixture entries using the existing demo files. `PhotosLargeLibraryTests` verifies newest-first entry, large counters and button separation, exact grid position on viewer return, album re-entry, deletion-neighbor recovery, relaunch, and rotation. It deletes only isolated demo entries.

```sh
python3 scripts/generate_artwork.py
swiftc -module-cache-path /tmp/photos-six-swift-cache scripts/generate_demo_video.swift -o /tmp/photos-six-video-generator
/tmp/photos-six-video-generator PhotosSix/Demo.bundle
python3 scripts/generate_localizations.py
python3 scripts/create_project.py
python3 scripts/verify_resources.py
xcodebuild -project PhotosSix.xcodeproj -scheme PhotosSix \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:PhotosSixTests -only-testing:PhotosSixUITests/PhotosSixUITests test
./scripts/serve_sim.sh <UDID>
```

Keep the serving terminal alive and open its printed localhost URL in Codex's in-app browser. Cleanup is scoped to that simulator. The photographic icon master and its prompt are in [artwork](artwork/icon-prompt.md).

The opt-in `PhotosCameraIntegrationTests` requires CameraSix installed on the same test simulator. Set `TEST_RUNNER_RUN_CAMERA_INTEGRATION=1` for `xcodebuild`, or `testRunnerEnv: {RUN_CAMERA_INTEGRATION: "1"}` with XcodeBuildMCP, and select that class. This test creates one illustrated camera capture in the simulator system library, opens it in PhotosSix by identifier, and returns to CameraSix. It should not be run against a personal physical library.

`PhotosSystemLibraryTests` is a separate opt-in check of actual PhotoKit album creation, rename, membership changes, and album deletion. Use `RUN_SYSTEM_LIBRARY_TESTS=1` through the test-runner environment after the simulator library is authorized and seeded. It preserves the source asset; approve only the native deletion request for its test-created empty **PhotosSix Renamed Verification** album. This one check is interactive because the OS owns album-deletion consent.

Debug builds also support `--device-smoke`: read authorized real media, decode/edit an image in memory, trim a short video in the app's private temporary output, remove that temporary movie, and write an aggregate `Documents/DeviceVerification/report.json`. This does not change the system library or export personal media outside the app.

Bundle ID: `com.yinyueyang.photossix`. Use your development team and an available signing slot for physical installation. See the [verification record](docs/verification.md).

## Service boundaries

Apple's [retired My Photo Stream service](https://support.apple.com/en-us/102645) is not recreated. The Photo Stream tab displays accessible iCloud Shared Albums; public PhotoKit access is primarily browsing, and creating/inviting/commenting on old shared streams is not implemented. iCloud account management, AirPlay screen mirroring, Wallpaper, RAW development, historical transition effects/music selection, and system-level replacement of Apple's Photos app remain OS-owned or outside this recreation. The app uses a crossfade slideshow rather than claiming every proprietary iOS 6 slideshow effect.
