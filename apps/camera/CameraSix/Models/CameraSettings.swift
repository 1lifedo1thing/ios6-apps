import Foundation

enum CaptureMode: String, Codable, CaseIterable {
  case photo, video, panorama
}

enum FlashMode: String, Codable, CaseIterable {
  case auto = "Auto"
  case on = "On"
  case off = "Off"
}

struct CameraSettings: Codable, Equatable {
  static let storageKey = "CameraSix.settings.v1"
  var grid = false
  var hdr = false
  var flash: FlashMode = .auto
  var keepNormal = true
  var saveToPhotos = true

  mutating func setHDR(_ enabled: Bool) {
    hdr = enabled
    if enabled { flash = .off }
  }

  mutating func setFlash(_ mode: FlashMode) {
    flash = mode
    if mode != .off { hdr = false }
  }

  static func load(_ defaults: UserDefaults = .standard) -> Self {
    guard let data = defaults.data(forKey: storageKey),
      let settings = try? JSONDecoder().decode(Self.self, from: data)
    else { return Self() }
    return settings
  }

  func save(_ defaults: UserDefaults = .standard) {
    if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.storageKey) }
  }
}

enum CameraTiming {
  static func timecode(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds))
    return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
  }
}
