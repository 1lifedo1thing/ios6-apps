import CoreLocation
import UIKit
import XCTest

@testable import MapsSix

@MainActor final class MapsSixTests: XCTestCase {
  func testLanguageFallbackAndChineseVariants() {
    for code in ["zh", "zh-Hant-TW", "ZH-hk", "zh-CN"] {
      XCTAssertEqual(AppLanguage.preferred([code]), .chinese)
    }
    for codes in [[], ["fr", "zh-Hans"], ["en-GB"]] {
      XCTAssertEqual(AppLanguage.preferred(codes), .english)
    }
    XCTAssertEqual(AppLanguage.chinese.placeName("臺灣廣場"), "台湾广场")
    XCTAssertEqual(MapPlace.landmarks[0].title(.chinese), "渡轮大厦")
    XCTAssertEqual(MapPlace.landmarks[0].title(.english), "Ferry Building")
  }
  func testLocalizedResourcesAndPlaceholders() throws {
    func strings(_ language: String) throws -> [String: String] {
      let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
      return try XCTUnwrap(
        NSDictionary(contentsOfFile: path + "/Localizable.strings") as? [String: String])
    }
    let en = try strings("en")
    let zh = try strings("zh-Hans")
    XCTAssertEqual(Set(en.keys), Set(zh.keys))
    for key in en.keys {
      XCTAssertFalse(zh[key]!.isEmpty)
      XCTAssertEqual(key.filter { $0 == "%" }.count, zh[key]!.filter { $0 == "%" }.count, key)
    }
    XCTAssertEqual(MapUnits.kilometres.distance(500, language: .chinese), "500 米")
    XCTAssertEqual(MapUnits.miles.distance(1609.344, language: .english), "1.0 mi")
  }
  func testLocationFreshnessAccuracyAndBounds() {
    let now = Date()
    func sample(_ lat: Double = 51.24, accuracy: Double = 5, age: Double = 0) -> CLLocation {
      CLLocation(
        coordinate: .init(latitude: lat, longitude: -0.59), altitude: 0,
        horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: now.addingTimeInterval(-age))
    }
    XCTAssertTrue(LocationService.valid(sample(), now: now))
    XCTAssertFalse(LocationService.valid(sample(91), now: now))
    XCTAssertFalse(LocationService.valid(sample(accuracy: -1), now: now))
    XCTAssertTrue(LocationService.valid(sample(accuracy: 500), now: now))
    XCTAssertFalse(LocationService.valid(sample(accuracy: 150_000), now: now))
    XCTAssertFalse(LocationService.valid(sample(age: 31), now: now))
    XCTAssertFalse(LocationService.valid(sample(age: -20), now: now))
  }
  func testProgressOnlyAdvancesNearNextManeuver() {
    let route = MapsStore.fixtureRoute()
    let start = route.steps[0].coordinate
    let next = route.steps[1].coordinate
    XCTAssertEqual(
      RouteProgress.nextIndex(
        current: 0, steps: route.steps,
        location: CLLocation(latitude: start.latitude, longitude: start.longitude)), 0)
    XCTAssertEqual(
      RouteProgress.nextIndex(
        current: 0, steps: route.steps,
        location: CLLocation(latitude: next.latitude, longitude: next.longitude)), 1)
    XCTAssertEqual(
      RouteProgress.nextIndex(
        current: 3, steps: route.steps,
        location: CLLocation(latitude: next.latitude, longitude: next.longitude)), 3)
  }
  @MainActor func testBookmarkRecentsAndPreferencesSurviveRelaunch() throws {
    let name = "MapsSixUnitTests-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let store = MapsStore(defaults: defaults, testing: true)
    let place = MapPlace.landmarks[0]
    store.toggleBookmark(place)
    store.remember(place)
    store.remember(place)
    store.style = .hybrid
    store.units = .miles
    store.traffic = true
    store.voice = false
    let restored = MapsStore(defaults: defaults, testing: true)
    XCTAssertEqual(restored.bookmarks, [place])
    XCTAssertEqual(restored.recents.count, 1)
    XCTAssertEqual(restored.style, .hybrid)
    XCTAssertEqual(restored.units, .miles)
    XCTAssertTrue(restored.traffic)
    XCTAssertFalse(restored.voice)
    restored.toggleBookmark(place)
    XCTAssertTrue(restored.bookmarks.isEmpty)
    restored.clearRecents()
    XCTAssertTrue(MapsStore(defaults: defaults, testing: true).recents.isEmpty)
  }
  @MainActor func testInvalidStoredCoordinatesAndDuplicateIDsAreRejected() throws {
    let name = "MapsSixInvalidTests-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    var bad = MapPlace.landmarks[0]
    bad.latitude = 100
    defaults.set(
      try JSONEncoder().encode([bad, MapPlace.landmarks[1], MapPlace.landmarks[1]]),
      forKey: "bookmarks")
    XCTAssertEqual(MapsStore(defaults: defaults).bookmarks, [MapPlace.landmarks[1]])
    defaults.set(Data("bad json".utf8), forKey: "bookmarks")
    XCTAssertTrue(MapsStore(defaults: defaults).bookmarks.isEmpty)
  }
  @MainActor func testSearchRouteCancellationAndNavigationLifecycle() async throws {
    let name = "MapsSixFlowTests-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let store = MapsStore(defaults: defaults, testing: true)
    store.query = "Ferry"
    store.submitSearch()
    for _ in 0..<50 where store.busy { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertEqual(store.selected?.id, "ferry")
    store.prepareDirections(to: MapPlace.landmarks[1])
    store.calculateRoute()
    for _ in 0..<50 where store.busy { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertEqual(store.routes.count, 1)
    store.voice = false
    store.startNavigation()
    XCTAssertTrue(store.navigating)
    store.previewStep(1)
    XCTAssertEqual(store.stepIndex, 1)
    store.previewStep(500)
    XCTAssertEqual(store.stepIndex, 1)
    store.endNavigation(clearRoute: true)
    XCTAssertFalse(store.navigating)
    XCTAssertTrue(store.routes.isEmpty)
    let previousSelection = store.selected
    store.query = "Tower"
    store.submitSearch()
    store.cancelOperation()
    try await Task.sleep(for: .milliseconds(30))
    XCTAssertFalse(store.busy)
    XCTAssertEqual(store.selected, previousSelection)
  }
  func testLocationGuidanceArrivalAndNewPlaceClearPreviousRoute() throws {
    let name = "MapsSixNavigationTests-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let store = MapsStore(defaults: defaults, testing: true)
    store.voice = false
    store.routes = [MapsStore.fixtureRoute()]
    store.routeDestination = MapPlace.landmarks[1]
    let idle = UIApplication.shared.isIdleTimerDisabled
    store.startNavigation()
    store.startNavigation()
    let point = store.routes[0].steps[1].coordinate
    store.location.onUpdate?(CLLocation(latitude: point.latitude, longitude: point.longitude))
    XCTAssertEqual(store.stepIndex, 1)
    XCTAssertEqual(store.maneuverSymbol, "arrow.turn.up.left")
    XCTAssertLessThan(try XCTUnwrap(store.remainingDistance), 1800)
    XCTAssertFalse(store.offRoute)
    let destination = MapPlace.landmarks[1].coordinate
    store.location.onUpdate?(
      CLLocation(latitude: destination.latitude, longitude: destination.longitude))
    XCTAssertTrue(store.arrived)
    XCTAssertFalse(store.navigating)
    XCTAssertTrue(store.routes.isEmpty)
    XCTAssertEqual(UIApplication.shared.isIdleTimerDisabled, idle)
    store.routes = [MapsStore.fixtureRoute()]
    store.routeDestination = MapPlace.landmarks[1]
    store.select(MapPlace.landmarks[0])
    XCTAssertTrue(store.routes.isEmpty)
  }
  func testStartupRequestsPermissionAndFollowsRealLocationUpdates() throws {
    let name = "MapsSixStartupTests-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let manager = FakeLocationManager()
    let location = LocationService(manager: manager)
    let store = MapsStore(defaults: defaults, locationService: location)
    XCTAssertEqual(store.region.center.latitude, 0)
    store.start()
    store.start()
    XCTAssertEqual(manager.permissionRequests, 1)
    XCTAssertTrue(store.follow)
    XCTAssertTrue(location.locating)
    manager.authorizationStatus = .authorizedWhenInUse
    location.authorizationChanged()
    XCTAssertEqual(manager.starts, 1)
    let first = CLLocation(latitude: 51.2423, longitude: -0.5906)
    location.receive([first])
    XCTAssertFalse(location.locating)
    XCTAssertEqual(try XCTUnwrap(store.cameraTarget).latitude, first.coordinate.latitude)
    let revision = store.cameraRevision
    location.receive([CLLocation(latitude: 51.243, longitude: -0.591)])
    XCTAssertGreaterThan(store.cameraRevision, revision)
    store.focus(MapPlace.landmarks[0].coordinate)
    let browsingRevision = store.cameraRevision
    location.receive([first])
    XCTAssertEqual(store.cameraRevision, browsingRevision)
    location.suspend()
    location.resume()
    XCTAssertEqual(manager.stops, 1)
    XCTAssertEqual(manager.starts, 2)
  }
  func testDeniedAndApproximateStartupAreHonestAndRecoverable() throws {
    let name = "MapsSixPermissionTests-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let manager = FakeLocationManager()
    manager.authorizationStatus = .denied
    let location = LocationService(manager: manager)
    let store = MapsStore(defaults: defaults, locationService: location)
    store.start()
    XCTAssertFalse(location.locating)
    XCTAssertNotNil(location.error)
    XCTAssertEqual(manager.starts, 0)
    manager.authorizationStatus = .authorizedWhenInUse
    manager.accuracyAuthorization = .reducedAccuracy
    location.authorizationChanged()
    let sample = CLLocation(
      coordinate: .init(latitude: 51.24, longitude: -0.59), altitude: 0,
      horizontalAccuracy: 2000, verticalAccuracy: -1, timestamp: Date())
    location.receive([sample])
    XCTAssertTrue(location.approximate)
    XCTAssertFalse(location.locating)
    XCTAssertNil(location.error)
    XCTAssertEqual(try XCTUnwrap(store.cameraTarget).latitude, 51.24)
  }
}

@MainActor private final class FakeLocationManager: MapsLocationManaging {
  weak var delegate: CLLocationManagerDelegate?
  var authorizationStatus: CLAuthorizationStatus = .notDetermined
  var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
  var desiredAccuracy: CLLocationAccuracy = 0
  var distanceFilter: CLLocationDistance = 0
  var permissionRequests = 0
  var starts = 0
  var stops = 0
  func requestWhenInUseAuthorization() { permissionRequests += 1 }
  func startUpdatingLocation() { starts += 1 }
  func stopUpdatingLocation() { stops += 1 }
}
