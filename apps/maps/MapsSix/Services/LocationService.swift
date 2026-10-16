import CoreLocation
import Observation

@MainActor
protocol MapsLocationManaging: AnyObject {
  var delegate: CLLocationManagerDelegate? { get set }
  var authorizationStatus: CLAuthorizationStatus { get }
  var accuracyAuthorization: CLAccuracyAuthorization { get }
  var desiredAccuracy: CLLocationAccuracy { get set }
  var distanceFilter: CLLocationDistance { get set }
  func requestWhenInUseAuthorization()
  func startUpdatingLocation()
  func stopUpdatingLocation()
}

extension CLLocationManager: MapsLocationManaging {}

@MainActor @Observable
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
  private let manager: any MapsLocationManaging
  var location: CLLocation?
  var authorization: CLAuthorizationStatus = .notDetermined
  var approximate = false
  var locating = false
  var error: String?
  var onUpdate: ((CLLocation) -> Void)?
  private var wantsLocation = false

  init(manager: (any MapsLocationManaging)? = nil) {
    self.manager = manager ?? CLLocationManager()
    super.init()
    self.manager.delegate = self
    self.manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    self.manager.distanceFilter = 8
    authorization = self.manager.authorizationStatus
    approximate = self.manager.accuracyAuthorization == .reducedAccuracy
  }
  func request() {
    wantsLocation = true
    locating = location.map { !Self.valid($0) } ?? true
    error = nil
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse: manager.startUpdatingLocation()
    case .denied, .restricted:
      locating = false
      error = L10n.text(
        "Location access is off. Enable it in Settings, or enter a starting address.")
    @unknown default: break
    }
  }
  func suspend() { manager.stopUpdatingLocation() }
  func resume() { if wantsLocation { request() } }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationChanged()
  }
  func authorizationChanged() {
    authorization = manager.authorizationStatus
    approximate = manager.accuracyAuthorization == .reducedAccuracy
    if wantsLocation { request() }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    receive(locations)
  }
  func receive(_ locations: [CLLocation]) {
    guard let sample = locations.last, Self.valid(sample) else { return }
    location = sample
    locating = false
    error = nil
    onUpdate?(sample)
  }
  static func valid(_ sample: CLLocation, now: Date = Date()) -> Bool {
    CLLocationCoordinate2DIsValid(sample.coordinate) && sample.horizontalAccuracy >= 0
      && sample.horizontalAccuracy.isFinite && sample.horizontalAccuracy <= 100_000
      && sample.timestamp.timeIntervalSince(now) > -30
      && sample.timestamp.timeIntervalSince(now) <= 5
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard (error as? CLError)?.code != .locationUnknown else { return }
    locating = false
    self.error = L10n.text("Your location is unavailable. Try again outdoors or enter an address.")
  }
}
