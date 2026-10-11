# CompassSix

A native iOS 17+ recreation of the iOS 6 Compass, with natural walnut artwork, a turned brass bezel, an ivory compass rose beneath shaded glass, a red north marker, a heading readout, coordinates, a Maps shortcut, and classic magnetic/true-north settings. This app runs on modern iOS; it is not an iOS 6 deployment target.

## Run

Open `CompassSix.xcodeproj` or the collection's `iOS6Apps.xcworkspace`, select `CompassSix`, and run on an iPhone or Simulator. The project includes app, unit-test, and UI-test targets. Code signing uses the collection's existing Personal Team; select your own team when using another account.

Keep derived data outside file-provider-managed folders to avoid code-signing errors caused by Finder metadata:

```sh
xcodebuild -project apps/compass/CompassSix.xcodeproj -scheme CompassSix \
  -destination 'platform=iOS Simulator,name=iPhone Air' \
  -derivedDataPath /tmp/compass-six-derived-data test
```

Use `python3 scripts/create_project.py` to regenerate the independent project and shared scheme. `python3 scripts/generate_artwork.py` packages the committed walnut and icon sources; it requires Pillow and makes no network calls. See [artwork provenance and generation prompts](artwork/README.md).

## Physical-device behavior

- Core Location supplies magnetometer heading through `startUpdatingHeading`; GPS course is never substituted for heading.
- Magnetic north works without location permission. Coordinates and true north require valid current location data. The app requests only foreground location access and does not upload or persist coordinates.
- True north is displayed only when Core Location supplies a valid true heading and a current location. Missing true north never silently becomes magnetic north.
- Invalid accuracy, stale samples, unavailable hardware, low accuracy, permission denial/restriction, and location timeouts have explicit states and recovery guidance.
- The screen's interface orientation updates `headingOrientation`; changing orientation invalidates the old reference-frame sample. Circular angle interpolation takes the shortest path through 0°/360°.
- Sensors stop when the app becomes inactive or enters the background. Returning starts fresh readings. Only the north preference persists.
- The system may show its own calibration prompt. Hold iPhone flat, away from magnets and metal, and follow calibration guidance. Accuracy remains dependent on the device and its environment.
- Maps opens the coordinates currently shown, using Apple's public Maps URL. Stale/unavailable coordinates cannot open Maps. Location and heading values are not written to debug output; Debug builds report receipt/accuracy metadata for local verification.

A free Personal Team permits only a limited number of simultaneously installed development apps. On 11 October 2026, the user authorized removal of the previously installed WeatherSix app to release a signing slot. The latest CompassSix build was installed on the physical iPhone Air (iOS 27.0.1), and real heading/location callbacks and independent runtime were verified. The user confirmed rotation accuracy, true-north operation, both landscape directions, and returning to the app. This is practical device validation, not a measured absolute-accuracy guarantee. See the [verification record](docs/verification.md) for evidence and limits. The installed development profile expires on 18 October 2026 at 10:05 Europe/London; renew the signed installation before then to continue using it.

## Simulator preview and browser

Simulator has no magnetometer. A normal launch honestly shows unavailable heading; set a simulated location to exercise coordinates and Maps. Open the info button and choose Start Preview to inspect the rotating compass with explicitly labeled sample data. Preview Maps is disabled to avoid presenting sample coordinates as the user's location.

Launch with `--demo` for a labeled sample heading of 222° and sample coordinates matching the historical reference. Preview turn controls move by 15°. Preview/fixture logic is compiled only for Simulator, and physical-device launches always use real sensors.

```sh
apps/compass/scripts/serve_sim.sh <simulator-udid>
```

Open the exact URL printed by `serve-sim` in Codex's in-app browser. Keep the terminal running; its exit trap stops only the helper for the supplied simulator. If Xcode 27 input is disconnected, the upstream repair command is `npx serve-sim@latest repair-input -d <simulator-udid>`; it restarts SpringBoard and closes running simulated apps, so restart the mirror and reopen Compass afterward.

## Language and accessibility

The first system/per-app preferred language selects the interface exactly as in Weather: Chinese variants use Simplified Chinese, English uses English, and other languages fall back to English. Direction names, coordinates, settings, accuracy/errors, accessibility labels, Home Screen name, and location permission explanation are localized. North preference remains unchanged across languages.

Buttons have at least 44-point touch regions. VoiceOver reads the compass bearing and coordinates without exposing decorative drawing elements. The settings page supports scrolling, Dynamic Type, and accessibility escape. Reduce Motion disables the rotating dial animation and substitutes a short fade for the information-page transition.

## Design and references

The main screen preserves Compass's specialized layout rather than adopting the Notes navigation frame. A single walnut surface continues behind the real system status area and below the independent toolbar through the bottom safe area. The compass combines directional brass reflections, concentric machining lines, rounded bevel shading, ivory microtexture, glass highlights, faceted rose artwork, and a raised center pivot. These material details remain stable while the localized dial card rotates. The app-owned information page uses classic chrome, dark linen, and grouped choices. Both use real system status bars and safe areas. See the [shared design language](../../docs/design-language.md).

The primary visual and functional reference is Apple's [iPhone User Guide for iOS 6, chapter 27, page 104](https://cdsassets.apple.com/live/6GJYWVAV/user/ma1658_iphone_ios6_user_guide.pdf). It depicts walnut wood, a brass compass, heading, coordinates, Maps, and magnetic/true-north selection. The original screenshot is used only as a reference. The walnut and app icon are newly generated artwork; the live dial uses original programmatic drawing. The icon also follows the 2009–2013 design documented in [Basic Apple Guy's icon history](https://basicappleguy.com/basicappleblog/ios-icon-history), with a thin dark perimeter around its pale calibration band, a delicate ivory dial, a faceted rose, a brass pivot, a white N inside its red marker, and the classic curved upper gloss. Historical pixels are not bundled.

Public sensor behavior follows Apple's [heading documentation](https://developer.apple.com/documentation/corelocation/getting-heading-and-course-information), [heading orientation](https://developer.apple.com/documentation/corelocation/cllocationmanager/headingorientation), and [heading accuracy](https://developer.apple.com/documentation/corelocation/clheading/headingaccuracy). The browser mirror uses [serve-sim](https://github.com/EvanBacon/serve-sim).

Modern system-owned permission dialogs, calibration alerts, Home Screen geometry, Maps, and device status indicators retain the current OS appearance. App dimensions adapt to today's displays and landscape; historical screenshot pixels are not stretched or embedded. This independent recreation is not affiliated with Apple.
