import CoreLocation
import MapKit
import Observation

struct PlaceResult: Identifiable {
  var id: String
  var place: ReminderPlace
  var address: String
}

@MainActor @Observable
final class ReminderLocation: NSObject, @preconcurrency CLLocationManagerDelegate {
  var permission: CLAuthorizationStatus
  var results: [PlaceResult] = []
  var searching = false
  var error: String?
  var currentPlace: ReminderPlace?
  @ObservationIgnored private let manager = CLLocationManager()
  @ObservationIgnored private var search: MKLocalSearch?
  @ObservationIgnored private var queryVersion = 0
  @ObservationIgnored private var locating = false

  override init() {
    permission = manager.authorizationStatus
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func requestCurrentLocation() {
    locating = true
    error = nil
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
    default:
      locating = false
      error = ReminderFailure.permission.localizedDescription
    }
  }

  func requestPermission() {
    if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
    if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
      error = ReminderFailure.permission.localizedDescription
    }
  }

  func searchAddress(_ query: String) async {
    queryVersion += 1
    let version = queryVersion
    search?.cancel()
    results = []
    error = nil
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      searching = false
      return
    }
    searching = true
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    if let current = manager.location {
      request.region = MKCoordinateRegion(
        center: current.coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
    }
    let operation = MKLocalSearch(request: request)
    search = operation
    do {
      let response = try await operation.start()
      guard version == queryVersion else { return }
      results = response.mapItems.enumerated().map { index, item in
        let coordinate = item.placemark.coordinate
        let address = [
          item.placemark.thoroughfare, item.placemark.locality, item.placemark.country,
        ].compactMap { $0 }.joined(separator: ", ")
        return PlaceResult(
          id: "\(coordinate.latitude),\(coordinate.longitude),\(index)",
          place: ReminderPlace(
            name: item.name ?? query, latitude: coordinate.latitude, longitude: coordinate.longitude
          ), address: address)
      }
      if results.isEmpty { error = ReminderFailure.location.localizedDescription }
    } catch {
      guard version == queryVersion else { return }
      self.error = ReminderFailure.location.localizedDescription
    }
    searching = false
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    permission = manager.authorizationStatus
    if locating && (permission == .authorizedAlways || permission == .authorizedWhenInUse) {
      manager.requestLocation()
    }
    if locating && (permission == .denied || permission == .restricted) {
      locating = false
      error = ReminderFailure.permission.localizedDescription
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    locating = false
    guard let location = locations.last else { return }
    currentPlace = ReminderPlace(
      name: L10n.text("Current Location"), latitude: location.coordinate.latitude,
      longitude: location.coordinate.longitude)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    locating = false
    self.error = ReminderFailure.location.localizedDescription
  }
}
