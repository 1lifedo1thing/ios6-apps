# MapsSix

A native iPhone Maps recreation inspired by the silver chrome, dimensional red pushpins, curled map corner, linen options panel, and green navigation signs of iOS 6.

## Run

Open `MapsSix.xcodeproj`, select the shared `MapsSix` scheme, and run on an iPhone or Simulator with iOS 17 or later. The collection's `iOS6Apps.xcworkspace` also includes this project. The bundle identifier is `com.yinyueyang.mapssix`. Device builds require your own development team and provisioning profile; the checked-in team follows the other apps in this collection.

No API keys, third-party SDKs, backend, or package installation are needed. Apple MapKit provides maps, search, route calculations, satellite imagery, 3D buildings, and available traffic data. An internet connection is required for uncached map data, search, routing, and print preparation.

For a simulator mirror in Codex:

```sh
./scripts/serve_sim.sh <simulator-udid>
```

Open the exact localhost URL printed by the command and keep its terminal alive. Cleanup is scoped to that simulator. If input fails while video remains live, run `npx --yes serve-sim@latest repair-input -d <simulator-udid>` and restart the mirror.

## Features

- Pan, pinch, rotate, tilt, current location, Standard/Satellite/Hybrid modes, 3D/Flyover imagery where available, and traffic overlays.
- Natural-language place/address search, a search result list, landmark shortcuts, and long-press or map-center dropped pins.
- Place details, phone/website links when returned by Apple, coordinate copying, location sharing, map printing, and opening a place in Apple Maps.
- Persistent bookmarks, deduplicated recent places, map type, traffic, distance units, and voice settings.
- Public transport handoff to Apple Maps. Driving and walking routes between typed addresses or the current location, route alternatives, distance/time summaries, a step list, and route overview.
- Foreground location-guided navigation with green signs, localized speech, maneuver progress, arrival detection, and throttled rerouting after moving away from a route. Manual previous/next controls preview instructions without requiring movement.
- English and Simplified Chinese using Weather's language rules: the first system/per-app language selects the UI; all Chinese variants use Simplified Chinese; unsupported languages fall back to English. Permissions, accessibility, distance formats, Home Screen name, errors, and built-in landmarks are localized. User data survives language changes.

On an ordinary launch, Maps requests foreground location permission and follows fresh device locations automatically. Before the first valid fix it shows a world overview and a locating message, rather than a hard-coded city. Manual browsing or choosing a place stops following; the location control resumes it. Approximate locations remain usable for browsing and are labeled, while navigation progression requires a precise sample. A route can be calculated without location permission by entering both addresses. Denied permission has a Settings recovery action. Foreground navigation keeps the display awake and releases that override when ended.

## Design and system boundaries

The [shared design language](../../docs/design-language.md) applies selectively. The main map retains its specialized edge-to-edge map, compact metal search bar, bottom controls, and physical page curl. Details and settings use pinstripes with separate silver navigation. Bookmarks follows the original white list surface, instruction above a 44-point title bar, blue Done button, and bottom silver segmented selector with an inset graphite selection. The silver header uses a continuous gradient and fine text relief instead of a hard horizontal gloss seam. Recents puts Clear in the upper-left corner. The third segment retains this app's landmark shortcuts. Body material continues behind the real status bar and bottom safe area; panel backgrounds remain confined to their own bounds. Controls respect device safe areas, both landscape directions, Dynamic Type, VoiceOver, and Reduce Motion. Artwork and textures are original procedural drawings; historical screenshots are not bundled assets.

The page turn bends a snapshot of the current map over a tessellated Metal surface. The back shows a faint reversed map impression, with curved lighting and a contact shadow. The idle fold uses reference-measured tip and quadratic-roll geometry, one continuous dark linen recess, and separate cast/contact shadows. On rounded displays, the paper tip and rolled edge sit inside the visible area, while the paper itself continues along its crease to the actual display edge. A deeper, curved recess joins the bottom boundary. The live MKMapView removes map pixels using the same local fold path as the SwiftUI drawing, so no map tongue remains beneath the lifted corner. This local paper mask does not duplicate the device perimeter or add an app wrapper. Cross-section lighting follows the curved roll, with a broad neutral highlight and a darker lower surface. Page-turn snapshots commit and flush temporary removal of the idle mask, then capture recent screen updates. This retains the complete map texture and prevents the idle cutout from appearing as a second shaded triangle on the lifted paper. Search focus and the entire search-results state remove the location/3D group and idle fold. The location/3D group uses safe-area layout without reapplying keyboard insets, and returns to the same baseline after selection or cancellation. Inactive map options are removed from the hierarchy. The sharp corner disappears while options are open; the corner and floating controls return only after the page has fully settled. Rendering stops between transitions, and Reduce Motion switches directly between stable states. Portrait and compact landscape keep separate, usable layouts.

The same live map fills the display behind the real status bar, independent search/navigation panel, bottom safe area, and landscape side insets. The location/3D group stays within the safe area. The page-curl touch region is anchored at the lower-right display edge, away from the home indicator, with its center inside the usable area. Standard maps use dark status text; satellite/hybrid maps use light status text, while supporting panels retain their light appearance. MapKit controls and attribution are inset around app chrome. Page-turn snapshots crop the corresponding area of that full-screen map rather than stretching it into the content viewport.

Historical references: the user-provided “iOS 6 地图介绍” conversation, [MacStories' 2012 hands-on review](https://www.macstories.net/reviews/hands-on-with-ios-6-maps/), and [Macworld's May 2013 screenshots of the Bookmarks/Recents interface](https://www.macworld.com/article/221085/how-to-clear-your-apple-maps-search-history.html). iOS 6 was released in 2012, after Steve Jobs's lifetime, and retains the earlier skeuomorphic design era.

MapKit uses current Apple cartography, attribution, place labels, routing, and coverage. Public APIs do not expose the retired 2012 map tiles, Yelp reviews, Siri's private Maps integration, or the original Apple navigation engine. Map labels and live maneuver text follow Apple's available language/data rather than an invented translation. Flyover is a pitched satellite/hybrid camera with a quarter-turn viewing control, not a claim of universal photogrammetry coverage or an official guided city tour.

App-owned controls and screens are classic styled. Keyboards, permission alerts, sharing, AirPrint, and external Apple Maps retain the current OS interface. “Report a Problem” opens the selected area in Apple Maps, where its own reporting tools are available. Printing prepares a current map image with visible pins and the selected route, preserving Apple's map attribution.

Navigation is a foreground companion; it does not provide lock-screen/background turn-by-turn service or offline route guarantees. Use the Apple Maps action for those system capabilities. Physical road navigation, speech output, GPS accuracy, and region-specific coverage require device and field testing beyond simulator regressions.

## Validation and reproducibility

See [verification](docs/verification.md) for actual results and remaining validation boundaries.

```sh
python3 scripts/create_project.py
python3 scripts/generate_localizations.py
python3 scripts/generate_artwork.py
python3 scripts/verify_resources.py
xcodebuild -project MapsSix.xcodeproj -scheme MapsSix \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -derivedDataPath /private/tmp/maps-six-derived test
```

Simulator-only `--ui-testing` uses isolated defaults and deterministic search/route fixtures; it is never enabled on a physical device. Ordinary simulator launches use real MapKit. The live UI regression launches without search/route fixtures, uses the simulator-only `--skip-initial-location` switch to avoid an unrelated permission prompt, and exercises Apple search and a walking route. Startup positioning is verified separately with injected location-manager tests and an ordinary simulator launch receiving public test coordinates. Neither simulator switch is honored on physical devices.
