import CoreLocation
import MapKit

struct MapPlace: Identifiable, Codable, Equatable {
  var id: String
  var name: String
  var chineseName: String?
  var address: String
  var chineseAddress: String?
  var latitude: Double
  var longitude: Double
  var phone: String?
  var website: URL?
  var isDroppedPin = false

  var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
  var isValid: Bool {
    latitude.isFinite && longitude.isFinite && CLLocationCoordinate2DIsValid(coordinate)
  }
  func title(_ language: AppLanguage = .current) -> String {
    if isDroppedPin { return L10n.text("Dropped Pin", language: language) }
    return language.placeName(language == .chinese ? chineseName ?? name : name)
  }
  func subtitle(_ language: AppLanguage = .current) -> String {
    language.placeName(language == .chinese ? chineseAddress ?? address : address)
  }
  var mapItem: MKMapItem {
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    item.name = title()
    item.phoneNumber = phone
    item.url = website
    return item
  }
  static func from(_ item: MKMapItem) -> Self {
    let point = item.placemark.coordinate
    return Self(
      id: String(
        format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), point.latitude,
        point.longitude),
      name: item.name ?? L10n.text("Place"), address: item.placemark.title ?? "",
      latitude: point.latitude, longitude: point.longitude, phone: item.phoneNumber,
      website: item.url)
  }
  static func pin(_ point: CLLocationCoordinate2D) -> Self {
    Self(
      id: UUID().uuidString, name: "Dropped Pin",
      address: String(
        format: "%.5f, %.5f", locale: Locale(identifier: "en_US_POSIX"), point.latitude,
        point.longitude),
      latitude: point.latitude, longitude: point.longitude, isDroppedPin: true)
  }
  static let landmarks: [Self] = [
    Self(
      id: "ferry", name: "Ferry Building", chineseName: "渡轮大厦",
      address: "1 Ferry Building, San Francisco, CA", chineseAddress: "美国加利福尼亚州旧金山渡轮大厦 1 号",
      latitude: 37.7955, longitude: -122.3937,
      website: URL(string: "https://www.ferrybuildingmarketplace.com")),
    Self(
      id: "coit", name: "Coit Tower", chineseName: "科伊特塔",
      address: "1 Telegraph Hill Blvd, San Francisco, CA", chineseAddress: "美国加利福尼亚州旧金山电报山大道 1 号",
      latitude: 37.8024, longitude: -122.4058),
    Self(
      id: "bridge", name: "Golden Gate Bridge", chineseName: "金门大桥",
      address: "Golden Gate Bridge, San Francisco, CA", chineseAddress: "美国加利福尼亚州旧金山金门大桥",
      latitude: 37.8199, longitude: -122.4783),
    Self(
      id: "surrey", name: "University of Surrey", chineseName: "萨里大学",
      address: "Stag Hill, Guildford GU2 7XH, United Kingdom",
      chineseAddress: "英国吉尔福德 Stag Hill，GU2 7XH",
      latitude: 51.2423, longitude: -0.5906),
    Self(
      id: "london", name: "Tower Bridge", chineseName: "伦敦塔桥",
      address: "Tower Bridge Road, London SE1 2UP", chineseAddress: "英国伦敦塔桥路，SE1 2UP",
      latitude: 51.5055, longitude: -0.0754),
  ]
}

enum MapStyle: String, CaseIterable, Identifiable {
  case standard = "Standard"
  case satellite = "Satellite"
  case hybrid = "Hybrid"
  var id: String { rawValue }
  func type(threeD: Bool) -> MKMapType {
    switch self {
    case .standard: .standard
    case .satellite: threeD ? .satelliteFlyover : .satellite
    case .hybrid: threeD ? .hybridFlyover : .hybrid
    }
  }
}

enum MapUnits: String, CaseIterable {
  case automatic = "Automatic"
  case kilometres = "Kilometres"
  case miles = "Miles"
  func distance(_ meters: Double, language: AppLanguage = .current) -> String {
    let imperial = self == .miles || (self == .automatic && Locale.current.measurementSystem == .us)
    let value = imperial ? meters / 1609.344 : meters / 1000
    if !imperial && meters < 1000 {
      return L10n.format("%d m", Int(max(0, meters).rounded()), language: language)
    }
    return L10n.format(imperial ? "%.1f mi" : "%.1f km", max(0, value), language: language)
  }
}

struct RouteInstruction: Identifiable {
  let id: Int
  let text: String
  let distance: Double
  let coordinate: CLLocationCoordinate2D
}

struct MapRoute: Identifiable {
  let id: String
  let name: String
  let distance: Double
  let duration: Double
  let polyline: MKPolyline
  let steps: [RouteInstruction]
  let advisory: [String]
  var time: String { L10n.format("%d min", max(1, Int((duration / 60).rounded(.up)))) }
}

enum RouteProgress {
  static func nextIndex(current: Int, steps: [RouteInstruction], location: CLLocation) -> Int {
    guard steps.indices.contains(current), current + 1 < steps.count else { return current }
    let next = steps[current + 1].coordinate
    let distance = location.distance(
      from: CLLocation(latitude: next.latitude, longitude: next.longitude))
    return distance < max(25, location.horizontalAccuracy) ? current + 1 : current
  }
}
