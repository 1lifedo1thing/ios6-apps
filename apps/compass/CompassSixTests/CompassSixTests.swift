import CoreLocation
import XCTest

@testable import CompassSix

final class CompassMathTests: XCTestCase {
  func testHeadingNormalizationAndShortestRotation() {
    XCTAssertEqual(CompassMath.normalize(-1), 359)
    XCTAssertEqual(CompassMath.normalize(721), 1)
    XCTAssertEqual(CompassMath.continuousAngle(from: 359, to: 1), 361)
    XCTAssertEqual(CompassMath.continuousAngle(from: 1, to: 359), -1)
    XCTAssertEqual(CompassMath.continuousAngle(from: 1081, to: 359), 1079)
    XCTAssertEqual(CompassMath.degrees(359.8), 0)
  }

  func testEightDirectionsAndBoundariesInBothLanguages() {
    for (value, english, chinese) in [
      (0.0, "N", "北"), (22.49, "N", "北"),
      (22.5, "NE", "东北"), (90, "E", "东"), (135, "SE", "东南"),
      (180, "S", "南"), (222, "SW", "西南"), (270, "W", "西"),
      (315, "NW", "西北"), (337.5, "N", "北"),
    ] {
      XCTAssertEqual(CompassMath.direction(value, language: .english), english)
      XCTAssertEqual(CompassMath.direction(value, language: .chinese), chinese)
    }
    XCTAssertEqual(CompassMath.bearing(222, language: .chinese), "222° 西南")
  }

  func testCoordinatesCarrySecondsAndUseCorrectHemispheres() {
    XCTAssertEqual(
      CompassMath.coordinate(37.321944, latitude: true, language: .english), "37°19′19″ N")
    XCTAssertEqual(
      CompassMath.coordinate(-122.028056, latitude: false, language: .english), "122°1′41″ W")
    XCTAssertEqual(CompassMath.coordinate(-0.5, latitude: true, language: .chinese), "0°30′0″ 南")
    XCTAssertEqual(
      CompassMath.coordinate(89.999999, latitude: true, language: .english), "90°0′0″ N")
    XCTAssertEqual(
      CompassMath.coordinate(179.999999, latitude: false, language: .chinese), "180°0′0″ 东")
  }

  func testInvalidAndStaleHeadingSamplesAreRejected() {
    let now = Date()
    func sample(
      _ magnetic: Double = 10, _ trueNorth: Double = 15, _ accuracy: Double = 2,
      _ timestamp: Date? = nil
    ) -> HeadingSample {
      HeadingSample(
        magnetic: magnetic, trueNorth: trueNorth, accuracy: accuracy, timestamp: timestamp ?? now)
    }
    XCTAssertEqual(sample().value(for: .trueNorth, now: now), 15)
    XCTAssertNil(sample(10, -1).value(for: .trueNorth, now: now))
    XCTAssertEqual(sample(10, -1).value(for: .magnetic, now: now), 10)
    XCTAssertNil(sample(10, 15, -1).value(for: .magnetic, now: now))
    XCTAssertNil(sample(.nan).value(for: .magnetic, now: now))
    XCTAssertNil(sample(360).value(for: .magnetic, now: now))
    XCTAssertNil(sample(10, 15, .infinity).value(for: .trueNorth, now: now))
    XCTAssertNil(sample(10, 15, 2, now.addingTimeInterval(-6)).value(for: .magnetic, now: now))
    XCTAssertNil(sample(10, 15, 2, now.addingTimeInterval(6)).value(for: .magnetic, now: now))
  }

  func testLocationValidationAndMapsCoordinates() {
    let now = Date()
    func location(_ coordinate: CLLocationCoordinate2D, _ accuracy: Double = 4, _ age: Double = 0)
      -> CLLocation
    {
      CLLocation(
        coordinate: coordinate, altitude: 0, horizontalAccuracy: accuracy,
        verticalAccuracy: -1, timestamp: now.addingTimeInterval(-age))
    }
    let coordinate = CLLocationCoordinate2D(latitude: 51.2362, longitude: -0.5704)
    let valid = location(coordinate)
    XCTAssertTrue(CompassMath.validLocation(valid, now: now))
    let url = URLComponents(url: CompassMath.mapsURL(for: valid)!, resolvingAgainstBaseURL: false)!
    XCTAssertEqual(url.host, "maps.apple.com")
    XCTAssertEqual(url.queryItems?.first(where: { $0.name == "ll" })?.value, "51.2362,-0.5704")
    XCTAssertNil(CompassMath.mapsURL(for: location(coordinate, 4, 31)))
    XCTAssertFalse(CompassMath.validLocation(location(coordinate, -1), now: now))
    XCTAssertFalse(CompassMath.validLocation(location(.init(latitude: 91, longitude: 0)), now: now))
    XCTAssertFalse(CompassMath.validLocation(location(coordinate, 4, -6), now: now))
  }

  func testLanguageRulesAndLocalizationCompleteness() throws {
    for language in ["zh-Hans", "zh-Hant", "zh-TW", "ZH-hk"] {
      XCTAssertEqual(AppLanguage.preferred([language]), .chinese)
    }
    XCTAssertEqual(AppLanguage.preferred(["en-GB", "zh-Hans"]), .english)
    XCTAssertEqual(AppLanguage.preferred(["fr", "zh-Hans"]), .english)
    XCTAssertEqual(AppLanguage.preferred([]), .english)
    let englishPath = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
    let chinesePath = try XCTUnwrap(Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"))
    let english = try XCTUnwrap(
      NSDictionary(contentsOfFile: englishPath + "/Localizable.strings") as? [String: String])
    let chinese = try XCTUnwrap(
      NSDictionary(contentsOfFile: chinesePath + "/Localizable.strings") as? [String: String])
    XCTAssertEqual(Set(english.keys), Set(chinese.keys))
    for key in english.keys {
      XCTAssertFalse(chinese[key]!.isEmpty)
      let englishFormats = key.components(separatedBy: "%").count
      XCTAssertEqual(englishFormats, chinese[key]!.components(separatedBy: "%").count, key)
    }
    for path in [englishPath, chinesePath] {
      let plist = try XCTUnwrap(
        NSDictionary(contentsOfFile: path + "/InfoPlist.strings") as? [String: String])
      XCTAssertNotNil(plist["CFBundleDisplayName"])
      XCTAssertNotNil(plist["NSLocationWhenInUseUsageDescription"])
    }
  }
}

@MainActor
final class CompassServiceTests: XCTestCase {
  private func makeService(_ manager: MockCompassManager? = nil) -> CompassService {
    let name = "CompassSixTests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    addTeardownBlock { defaults.removePersistentDomain(forName: name) }
    return CompassService(manager: manager ?? MockCompassManager(), defaults: defaults)
  }

  private func sample(_ magnetic: Double = 359, trueNorth: Double = 12, accuracy: Double = 5)
    -> HeadingSample
  {
    HeadingSample(magnetic: magnetic, trueNorth: trueNorth, accuracy: accuracy, timestamp: .now)
  }

  func testMagneticHeadingWorksWithoutLocationAndPermissionDenial() {
    let manager = MockCompassManager()
    manager.authorizationStatus = .denied
    let service = makeService(manager)
    service.start()
    defer { service.stop() }
    service.receive(sample())
    XCTAssertEqual(service.heading, 359)
    XCTAssertNil(service.location)
    XCTAssertEqual(manager.headingStarts, 1)
    XCTAssertEqual(manager.locationStarts, 0)
    XCTAssertEqual(manager.permissionRequests, 0)
    service.select(.trueNorth)
    XCTAssertNil(service.heading)
    XCTAssertTrue(service.headingMessage.hasPrefix("True north"))
    service.select(.magnetic)
    XCTAssertEqual(service.heading, 359)
  }

  func testPermissionGrantAndRevocationKeepTrueNorthHonest() {
    let manager = MockCompassManager()
    let service = makeService(manager)
    service.start()
    defer { service.stop() }
    XCTAssertEqual(manager.permissionRequests, 1)
    manager.authorizationStatus = .authorizedWhenInUse
    service.updateAuthorization()
    XCTAssertEqual(manager.locationStarts, 1)
    service.select(.trueNorth)
    service.receive(sample())
    XCTAssertNil(service.heading)
    service.receive([CLLocation(latitude: 51.2, longitude: -0.5)])
    XCTAssertEqual(service.heading, 12)
    manager.authorizationStatus = .denied
    service.updateAuthorization()
    XCTAssertNil(service.location)
    XCTAssertNil(service.heading)
    service.select(.magnetic)
    XCTAssertEqual(service.heading, 359)
  }

  func testInvalidAccuracyClearsBearingAndValidSampleRecovers() {
    let service = makeService()
    service.start()
    defer { service.stop() }
    service.receive(sample())
    service.receive(sample(10, accuracy: -1))
    XCTAssertNil(service.heading)
    XCTAssertNil(service.accuracy)
    XCTAssertTrue(service.headingMessage.contains("calibrate"))
    service.receive(sample(1, accuracy: 35))
    XCTAssertEqual(service.heading, 1)
    XCTAssertTrue(service.headingMessage.contains("Low accuracy"))
    service.receive(sample(2, accuracy: 3))
    XCTAssertEqual(service.heading, 2)
    XCTAssertEqual(service.headingMessage, "")
  }

  func testStaleSamplesAndLocationsAreRemoved() {
    let service = makeService()
    service.start()
    defer { service.stop() }
    service.receive([CLLocation(latitude: 51, longitude: 0)])
    service.receive(sample())
    service.refresh(now: .now.addingTimeInterval(31))
    XCTAssertNil(service.heading)
    XCTAssertNil(service.location)
    XCTAssertTrue(service.locationMessage.contains("out of date"))
  }

  func testTrueNorthUnavailableNeverSubstitutesMagneticHeading() {
    let service = makeService()
    service.start()
    defer { service.stop() }
    service.receive([CLLocation(latitude: 51, longitude: 0)])
    service.select(.trueNorth)
    service.receive(sample(100, trueNorth: -1))
    XCTAssertNil(service.heading)
    service.receive(sample(100, trueNorth: 103))
    XCTAssertEqual(service.heading, 103)
  }

  func testLifecycleStopsSensorsAndIgnoresLateCallbacks() {
    let manager = MockCompassManager()
    let service = makeService(manager)
    service.start()
    service.start()
    XCTAssertEqual(manager.headingStarts, 1)
    service.receive(sample())
    service.stop()
    XCTAssertEqual(manager.headingStops, 1)
    XCTAssertEqual(manager.locationStops, 1)
    service.receive(sample(50))
    service.receive([CLLocation(latitude: 51, longitude: 0)])
    XCTAssertNil(service.heading)
    XCTAssertNil(service.location)
    service.start()
    XCTAssertEqual(manager.headingStarts, 2)
    XCTAssertNil(service.heading)
    service.stop()
  }

  func testInterfaceOrientationChangesInvalidateOldReferenceFrame() {
    let manager = MockCompassManager()
    let service = makeService(manager)
    service.start()
    defer { service.stop() }
    service.receive(sample())
    service.updateOrientation(.landscapeLeft)
    XCTAssertEqual(manager.headingOrientation, .landscapeRight)
    XCTAssertNil(service.heading)
    service.receive(sample(45))
    service.updateOrientation(.landscapeLeft)
    XCTAssertEqual(service.heading, 45)
    service.updateOrientation(.landscapeRight)
    XCTAssertEqual(manager.headingOrientation, .landscapeLeft)
    XCTAssertNil(service.heading)
    service.updateOrientation(.portrait)
    XCTAssertEqual(manager.headingOrientation, .portrait)
  }

  func testUnsupportedSensorAndTimeoutStates() {
    let manager = MockCompassManager()
    manager.supportsHeading = false
    let service = makeService(manager)
    service.start()
    XCTAssertEqual(manager.headingStarts, 0)
    XCTAssertTrue(service.headingMessage.contains("unavailable"))
    service.stop()
    manager.supportsHeading = true
    manager.authorizationStatus = .authorizedWhenInUse
    service.start()
    service.refresh(now: .now.addingTimeInterval(21))
    XCTAssertTrue(service.headingMessage.contains("No compass data"))
    XCTAssertTrue(service.locationMessage.contains("outdoors"))
    service.stop()
  }

  func testNorthReferencePersistsSeparatelyFromReadings() {
    let name = "CompassSixPersistence-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let service = CompassService(manager: MockCompassManager(), defaults: defaults)
    service.select(.trueNorth)
    let restored = CompassService(manager: MockCompassManager(), defaults: defaults)
    XCTAssertEqual(restored.reference, .trueNorth)
    XCTAssertNil(restored.heading)
    XCTAssertNil(restored.location)
  }
}

@MainActor
private final class MockCompassManager: CompassManaging {
  weak var delegate: CLLocationManagerDelegate?
  var authorizationStatus: CLAuthorizationStatus = .notDetermined
  var headingOrientation: CLDeviceOrientation = .portrait
  var supportsHeading = true
  var permissionRequests = 0
  var headingStarts = 0
  var headingStops = 0
  var locationStarts = 0
  var locationStops = 0
  func requestWhenInUseAuthorization() { permissionRequests += 1 }
  func startUpdatingHeading() { headingStarts += 1 }
  func stopUpdatingHeading() { headingStops += 1 }
  func startUpdatingLocation() { locationStarts += 1 }
  func stopUpdatingLocation() { locationStops += 1 }
}
