import CoreLocation
import Foundation

enum NorthReference: String, CaseIterable {
  case magnetic, trueNorth

  var title: String { self == .magnetic ? "Magnetic North" : "True North" }
}

struct HeadingSample {
  let magnetic: Double
  let trueNorth: Double
  let accuracy: Double
  let timestamp: Date

  func value(for reference: NorthReference, now: Date = .now) -> Double? {
    guard accuracy.isFinite, accuracy >= 0,
      timestamp.timeIntervalSince(now) <= 5, now.timeIntervalSince(timestamp) <= 5,
      magnetic.isFinite, (0..<360).contains(magnetic)
    else { return nil }
    let value = reference == .magnetic ? magnetic : trueNorth
    guard value.isFinite, (0..<360).contains(value) else { return nil }
    return value
  }
}

enum CompassMath {
  static func normalize(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    let remainder = value.truncatingRemainder(dividingBy: 360)
    return remainder < 0 ? remainder + 360 : remainder
  }

  static func continuousAngle(from previous: Double, to heading: Double) -> Double {
    let delta = normalize(heading - normalize(previous) + 180) - 180
    return previous + delta
  }

  static func degrees(_ heading: Double) -> Int { Int(normalize(heading).rounded()) % 360 }

  static func direction(_ heading: Double, language: AppLanguage = .current) -> String {
    let keys = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return L10n.text(keys[Int((normalize(heading) + 22.5) / 45) % 8], language: language)
  }

  static func bearing(_ heading: Double, language: AppLanguage = .current) -> String {
    "\(degrees(heading))° \(direction(heading, language: language))"
  }

  static func coordinate(_ value: Double, latitude: Bool, language: AppLanguage = .current)
    -> String
  {
    let seconds = Int((abs(value) * 3600).rounded())
    let degrees = seconds / 3600
    let minutes = seconds % 3600 / 60
    let remainder = seconds % 60
    let key = latitude ? (value < 0 ? "S" : "N") : (value < 0 ? "W" : "E")
    return "\(degrees)°\(minutes)′\(remainder)″ \(L10n.text(key, language: language))"
  }

  static func coordinates(_ location: CLLocation, language: AppLanguage = .current) -> String {
    coordinate(location.coordinate.latitude, latitude: true, language: language)
      + ", " + coordinate(location.coordinate.longitude, latitude: false, language: language)
  }

  static func validLocation(_ location: CLLocation, now: Date = .now) -> Bool {
    CLLocationCoordinate2DIsValid(location.coordinate) && location.horizontalAccuracy.isFinite
      && location.horizontalAccuracy >= 0 && now.timeIntervalSince(location.timestamp) <= 30
      && location.timestamp.timeIntervalSince(now) <= 5
  }

  static func mapsURL(for location: CLLocation) -> URL? {
    guard validLocation(location) else { return nil }
    var url = URLComponents(string: "https://maps.apple.com/")!
    url.queryItems = [
      URLQueryItem(
        name: "ll", value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"),
      URLQueryItem(name: "q", value: L10n.text("Current Location")),
    ]
    return url.url
  }
}
