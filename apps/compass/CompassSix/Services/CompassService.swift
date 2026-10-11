import CoreLocation
import Observation
import UIKit

@MainActor
protocol CompassManaging: AnyObject {
  var delegate: CLLocationManagerDelegate? { get set }
  var authorizationStatus: CLAuthorizationStatus { get }
  var headingOrientation: CLDeviceOrientation { get set }
  var supportsHeading: Bool { get }
  func requestWhenInUseAuthorization()
  func startUpdatingHeading()
  func stopUpdatingHeading()
  func startUpdatingLocation()
  func stopUpdatingLocation()
}

extension CLLocationManager: CompassManaging {
  var supportsHeading: Bool { Self.headingAvailable() }
}

@MainActor @Observable
final class CompassService: NSObject, @preconcurrency CLLocationManagerDelegate {
  private(set) var heading: Double?
  private(set) var dialAngle = 0.0
  private(set) var accuracy: Double?
  private(set) var location: CLLocation?
  private(set) var headingMessage = "Waiting for compass…"
  private(set) var locationMessage = "Waiting for location…"
  private(set) var authorization: CLAuthorizationStatus = .notDetermined
  private(set) var active = false
  private(set) var demo = false
  private(set) var sample: HeadingSample?
  private(set) var reference: NorthReference
  private let manager: any CompassManaging
  private let defaults: UserDefaults
  private var freshnessTask: Task<Void, Never>?
  private var locationStarted: Date?
  private var headingStarted: Date?
  private var simulatedAngle = 222.0
  private var fixture: String?
  private var reportedHeading = false
  private var reportedLocation = false

  init(manager: (any CompassManaging)? = nil, defaults: UserDefaults = .standard) {
    let manager = manager ?? CLLocationManager()
    self.manager = manager
    self.defaults = defaults
    reference =
      NorthReference(rawValue: defaults.string(forKey: "northReference") ?? "") ?? .magnetic
    super.init()
    if let realManager = manager as? CLLocationManager {
      realManager.headingFilter = kCLHeadingFilterNone
      realManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
      realManager.distanceFilter = kCLDistanceFilterNone
    }
    authorization = manager.authorizationStatus
    manager.delegate = self
  }

  func start() {
    guard !active else { return }
    active = true
    if demo {
      updateDemo()
    } else {
      authorization = manager.authorizationStatus
      headingStarted = .now
      headingMessage =
        manager.supportsHeading ? "Waiting for compass…" : "Compass unavailable on this device."
      if manager.supportsHeading { manager.startUpdatingHeading() }
      // Magnetic heading does not depend on location authorization.
      updateAuthorization(requestIfNeeded: true)
    }
    freshnessTask = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        guard let self else { return }
        if self.demo { self.updateDemo() } else { self.refresh() }
      }
    }
  }

  func stop() {
    active = false
    freshnessTask?.cancel()
    freshnessTask = nil
    manager.stopUpdatingHeading()
    manager.stopUpdatingLocation()
    sample = nil
    heading = nil
    accuracy = nil
    location = nil
    headingStarted = nil
    locationStarted = nil
  }

  func select(_ reference: NorthReference) {
    self.reference = reference
    defaults.set(reference.rawValue, forKey: "northReference")
    refresh()
  }

  func requestLocation() {
    updateAuthorization(requestIfNeeded: true)
  }

  func updateOrientation(_ orientation: UIInterfaceOrientation) {
    let newOrientation: CLDeviceOrientation
    switch orientation {
    case .portrait: newOrientation = .portrait
    case .portraitUpsideDown: newOrientation = .portraitUpsideDown
    // Interface and physical-device landscape directions are opposite.
    case .landscapeLeft: newOrientation = .landscapeRight
    case .landscapeRight: newOrientation = .landscapeLeft
    default: return
    }
    guard manager.headingOrientation != newOrientation else { return }
    manager.headingOrientation = newOrientation
    sample = nil
    heading = nil
    headingMessage =
      manager.supportsHeading ? "Waiting for compass…" : "Compass unavailable on this device."
    headingStarted = .now
    if demo { updateDemo() }
  }

  func receive(_ sample: HeadingSample) {
    guard active else { return }
    self.sample = sample
    refresh()
  }

  func receive(_ locations: [CLLocation]) {
    guard active else { return }
    guard let received = locations.last(where: { CompassMath.validLocation($0) }) else { return }
    location = received
    locationMessage = ""
    refresh()
  }

  func refresh(now: Date = .now) {
    if let location, !CompassMath.validLocation(location, now: now) {
      self.location = nil
      locationMessage = "Location is out of date. Waiting for an update…"
    }
    if location == nil, locationMessage == "Waiting for location…",
      let locationStarted, now.timeIntervalSince(locationStarted) > 20
    {
      locationMessage = "Couldn't find your location. Try again outdoors."
    }
    guard let sample else {
      heading = nil
      accuracy = nil
      if manager.supportsHeading, let headingStarted, now.timeIntervalSince(headingStarted) > 10 {
        headingMessage = "No compass data. Move away from magnets and try again."
      }
      return
    }
    guard let magnetic = sample.value(for: .magnetic, now: now) else {
      heading = nil
      accuracy = nil
      headingMessage =
        sample.accuracy < 0
        ? "Move iPhone in a figure eight to calibrate."
        : "Compass reading is out of date. Waiting for an update…"
      return
    }
    let selected: Double?
    if reference == .trueNorth {
      selected = location == nil ? nil : sample.value(for: .trueNorth, now: now)
    } else {
      selected = magnetic
    }
    guard let selected else {
      heading = nil
      accuracy = nil
      headingMessage =
        "True north needs a current location. Magnetic north is available in settings."
      return
    }
    heading = selected
    accuracy = sample.accuracy
    dialAngle = CompassMath.continuousAngle(from: dialAngle, to: selected)
    headingMessage = sample.accuracy > 20 ? "Low accuracy. Move away from magnets and metal." : ""
  }

  func updateAuthorization(requestIfNeeded: Bool = false) {
    guard active, !demo else { return }
    authorization = manager.authorizationStatus
    switch authorization {
    case .notDetermined:
      locationMessage = "Allow location for coordinates and true north."
      if requestIfNeeded { manager.requestWhenInUseAuthorization() }
    case .authorizedAlways, .authorizedWhenInUse:
      if location == nil { locationMessage = "Waiting for location…" }
      locationStarted = .now
      manager.startUpdatingLocation()
    case .denied, .restricted:
      manager.stopUpdatingLocation()
      location = nil
      locationMessage =
        authorization == .restricted
        ? "Location access is restricted."
        : "Location access is off. Enable it in Settings."
    @unknown default:
      locationMessage = "Location is unavailable."
    }
    refresh()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    updateAuthorization()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    #if DEBUG
      if !reportedHeading, newHeading.headingAccuracy >= 0 {
        reportedHeading = true
        print(
          "CompassSix hardware heading received; accuracy=\(newHeading.headingAccuracy); trueNorthAvailable=\(newHeading.trueHeading >= 0)"
        )
      }
    #endif
    receive(
      HeadingSample(
        magnetic: newHeading.magneticHeading, trueNorth: newHeading.trueHeading,
        accuracy: newHeading.headingAccuracy, timestamp: newHeading.timestamp))
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    #if DEBUG
      if !reportedLocation, locations.contains(where: { CompassMath.validLocation($0) }) {
        reportedLocation = true
        print("CompassSix current location received; coordinate values omitted")
      }
    #endif
    receive(locations)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard active, !demo else { return }
    if let error = error as? CLError, error.code == .denied {
      location = nil
      manager.stopUpdatingLocation()
      locationMessage = "Location access is off. Enable it in Settings."
    } else {
      locationMessage = "Couldn't find your location. Try again outdoors."
    }
    refresh()
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }

  // Simulator fixtures never replace physical-device sensor data.
  func configurePreview(arguments: [String]) {
    #if targetEnvironment(simulator)
      if arguments.contains("--demo") || arguments.contains("--uitesting") {
        demo = true
        fixture =
          arguments.contains("--denied")
          ? "denied" : arguments.contains("--invalid") ? "invalid" : nil
        updateDemo()
      }
    #endif
  }

  func togglePreview() {
    #if targetEnvironment(simulator)
      let wasActive = active
      stop()
      demo.toggle()
      fixture = nil
      if wasActive { start() }
    #endif
  }

  func turnPreview(by degrees: Double) {
    guard demo else { return }
    simulatedAngle = CompassMath.normalize(simulatedAngle + degrees)
    updateDemo()
  }

  private func updateDemo() {
    #if targetEnvironment(simulator)
      guard demo else { return }
      authorization = fixture == "denied" ? .denied : .authorizedWhenInUse
      location = fixture == "denied" ? nil : CLLocation(latitude: 37.321944, longitude: -122.028056)
      locationMessage = fixture == "denied" ? "Location access is off. Enable it in Settings." : ""
      sample = HeadingSample(
        magnetic: simulatedAngle, trueNorth: CompassMath.normalize(simulatedAngle + 13),
        accuracy: fixture == "invalid" ? -1 : 5, timestamp: .now)
      refresh()
    #endif
  }
}
