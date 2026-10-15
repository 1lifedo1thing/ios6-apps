import CoreLocation
import Foundation
import Photos

struct PhotoItem: Identifiable, Equatable {
  let id: String
  let date: Date
  let width: Int
  let height: Int
  let duration: Double
  let isVideo: Bool
  let latitude: Double?
  let longitude: Double?
  let file: URL?
  var asset: PHAsset?

  var coordinate: CLLocationCoordinate2D? {
    guard let latitude, let longitude else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
  static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.date == rhs.date }
  init(asset: PHAsset) {
    id = asset.localIdentifier
    date = asset.creationDate ?? .distantPast
    width = asset.pixelWidth
    height = asset.pixelHeight
    duration = asset.duration
    isVideo = asset.mediaType == .video
    latitude = asset.location?.coordinate.latitude
    longitude = asset.location?.coordinate.longitude
    file = nil
    self.asset = asset
  }
  init(
    id: String, date: Date, width: Int = 1200, height: Int = 900, duration: Double = 0,
    isVideo: Bool = false, latitude: Double? = nil, longitude: Double? = nil, file: URL?
  ) {
    self.id = id
    self.date = date
    self.width = width
    self.height = height
    self.duration = duration
    self.isVideo = isVideo
    self.latitude = latitude
    self.longitude = longitude
    self.file = file
  }
}

struct PhotoAlbum: Identifiable, Equatable {
  let id: String
  var title: String
  var items: [PhotoItem]
  var collection: PHAssetCollection?
  var editable = false
  var shared = false
  var builtIn = false
  var displayTitle: String { builtIn ? L10n.text(title) : title }
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.title == rhs.title && lhs.items == rhs.items
  }
}

struct DemoAlbum: Codable {
  var id: String
  var title: String
  var ids: [String]
}

struct DemoIndex: Codable {
  var albums: [DemoAlbum] = []
  var deleted: Set<String> = []
  var addedFiles: [String] = []
}

enum PhotoFailure: LocalizedError {
  case permission, unavailable, save, emptyName, noCamera
  var errorDescription: String? {
    switch self {
    case .permission: return L10n.text("Allow Photos access in Settings to use your library.")
    case .unavailable:
      return L10n.text("This item could not be downloaded. Check your connection and try again.")
    case .save: return L10n.text("Changes could not be saved. Please try again.")
    case .emptyName: return L10n.text("Enter an album name.")
    case .noCamera:
      return L10n.text("Install CameraSix to take photos. Both apps use the system photo library.")
    }
  }
}

enum PhotoLink {
  static func assetID(from url: URL) -> String? {
    guard url.scheme == "photossix", url.host == "library" else { return nil }
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
      .first { $0.name == "asset" }?.value
  }
  static let camera = URL(string: "camerasix://capture?returnTo=photos")!
}
