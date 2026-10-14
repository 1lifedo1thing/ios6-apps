import AVFoundation
import Photos
import UIKit

struct CapturedMedia: Identifiable, Codable, Equatable {
  enum Kind: String, Codable { case photo, video, panorama }
  let id: UUID
  let filename: String
  let thumbnail: String
  let kind: Kind
  let createdAt: Date
  var isHDR: Bool
  var savedToPhotos = false
}

@MainActor
final class MediaLibrary: ObservableObject {
  @Published private(set) var items: [CapturedMedia] = []
  let directory: URL
  private let work = DispatchQueue(label: "CameraSix.library", qos: .userInitiated)
  private var photoSaves: [UUID: Task<Void, Error>] = [:]

  init(directory: URL? = nil) {
    self.directory =
      directory
      ?? FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask)[0].appendingPathComponent("CameraSix", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
      let index = self.directory.appendingPathComponent("index.json")
      if FileManager.default.fileExists(atPath: index.path) {
        items = try JSONDecoder().decode([CapturedMedia].self, from: Data(contentsOf: index))
          .filter {
            FileManager.default.fileExists(
              atPath: self.directory.appendingPathComponent($0.filename).path)
          }
      }
    } catch { print("CameraSix library could not be loaded: \(error)") }
  }

  func url(for item: CapturedMedia) -> URL { directory.appendingPathComponent(item.filename) }
  func thumbnail(for item: CapturedMedia) -> UIImage? {
    UIImage(contentsOfFile: directory.appendingPathComponent(item.thumbnail).path)
  }

  func addPhoto(_ data: Data, kind: CapturedMedia.Kind = .photo, hdr: Bool = false) async throws
    -> CapturedMedia
  {
    let id = UUID()
    let item = CapturedMedia(
      id: id, filename: "\(id).jpg", thumbnail: "\(id)-thumb.jpg",
      kind: kind, createdAt: .now, isHDR: hdr)
    let directory = directory
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      work.async {
        do {
          guard let image = UIImage(data: data),
            let thumbnail = ImageProcessing.upright(image, maxDimension: 240).jpegData(
              compressionQuality: 0.8)
          else { throw ImageProcessingError.invalidImage }
          try data.write(to: directory.appendingPathComponent(item.filename), options: .atomic)
          try thumbnail.write(
            to: directory.appendingPathComponent(item.thumbnail), options: .atomic)
          continuation.resume()
        } catch { continuation.resume(throwing: error) }
      }
    }
    items.insert(item, at: 0)
    try saveIndex()
    return item
  }

  func addVideo(_ temporary: URL) async throws -> CapturedMedia {
    let id = UUID()
    let item = CapturedMedia(
      id: id, filename: "\(id).mov", thumbnail: "\(id)-thumb.jpg",
      kind: .video, createdAt: .now, isHDR: false)
    let destination = url(for: item)
    try FileManager.default.copyItem(at: temporary, to: destination)
    try? FileManager.default.removeItem(at: temporary)
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: destination))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 240, height: 240)
    if let frame = try? await generator.image(at: .zero),
      let data = UIImage(cgImage: frame.image).jpegData(compressionQuality: 0.8)
    {
      try? data.write(to: directory.appendingPathComponent(item.thumbnail), options: .atomic)
    }
    items.insert(item, at: 0)
    try saveIndex()
    return item
  }

  func saveToPhotos(_ item: CapturedMedia) async throws {
    if let pending = photoSaves[item.id] { return try await pending.value }
    guard !items.first(where: { $0.id == item.id }).map(\.savedToPhotos, default: false) else {
      return
    }
    let task = Task { try await writeToPhotos(item) }
    photoSaves[item.id] = task
    defer { photoSaves[item.id] = nil }
    try await task.value
  }

  private func writeToPhotos(_ item: CapturedMedia) async throws {
    var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    if status == .notDetermined {
      status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
    guard status == .authorized || status == .limited else { throw LibraryError.permissionDenied }
    let fileURL = url(for: item)
    try await PHPhotoLibrary.shared().performChanges {
      let request = PHAssetCreationRequest.forAsset()
      request.creationDate = item.createdAt
      request.addResource(
        with: item.kind == .video ? .video : .photo, fileURL: fileURL, options: nil)
    }
    if let index = items.firstIndex(where: { $0.id == item.id }) {
      items[index].savedToPhotos = true
    }
    try saveIndex()
  }

  func removeLocal(_ item: CapturedMedia) throws {
    // Only the app's local copy is removed. Its Photos asset is never silently deleted.
    let previous = items
    items.removeAll { $0.id == item.id }
    do { try saveIndex() } catch {
      items = previous
      throw error
    }
    try? FileManager.default.removeItem(at: url(for: item))
    try? FileManager.default.removeItem(at: directory.appendingPathComponent(item.thumbnail))
  }

  private func saveIndex() throws {
    try JSONEncoder().encode(items).write(
      to: directory.appendingPathComponent("index.json"), options: .atomic)
  }
}

enum LibraryError: Error { case permissionDenied }

extension Optional {
  fileprivate func map<T>(_ keyPath: KeyPath<Wrapped, T>, default fallback: T) -> T {
    map { $0[keyPath: keyPath] } ?? fallback
  }
}
