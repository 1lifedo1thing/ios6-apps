import AVFoundation
import ImageIO
import Observation
import Photos
import UIKit

@Observable @MainActor
final class PhotoLibrary {
  private(set) var albums: [PhotoAlbum] = []
  private(set) var authorization = PHAuthorizationStatus.notDetermined
  private(set) var loading = false
  var message: String?
  var busy = false
  private(set) var isDemo: Bool
  let directory: URL
  private(set) var browsing: PhotoBrowseState
  private var demoIndex = DemoIndex()
  private var observer: LibraryObserver?
  private var observing = false
  private let manager = PHCachingImageManager()

  init(demo: Bool? = nil, directory: URL? = nil) {
    let args = ProcessInfo.processInfo.arguments
    let demoMode = demo ?? (args.contains("--demo") || args.contains("--ui-testing"))
    isDemo = demoMode
    self.directory =
      directory
      ?? FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask)[0].appendingPathComponent(
        args.contains("--ui-testing") ? "PhotosSix-UI" : "PhotosSix-Demo")
    if args.contains("--ui-testing"), !args.contains("--preserve-demo"), directory == nil {
      try? FileManager.default.removeItem(at: self.directory)
    }
    try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    browsing = PhotoBrowseState(directory: self.directory, demo: demoMode)
    if let data = try? Data(contentsOf: self.directory.appendingPathComponent("index.json")),
      let index = try? JSONDecoder().decode(DemoIndex.self, from: data)
    {
      demoIndex = index
    }
    if isDemo {
      authorization = .authorized
      loadDemo()
    }
  }

  var allItems: [PhotoItem] { albums.first(where: { $0.id == "roll" })?.items ?? [] }
  var sharedAlbums: [PhotoAlbum] { albums.filter(\.shared) }
  var canRead: Bool { authorization == .authorized || authorization == .limited }

  func activate(request: Bool = false) async {
    guard !isDemo else { return }
    authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if request && authorization == .notDetermined {
      authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
    if canRead {
      if !observing {
        let observer = LibraryObserver { [weak self] in self?.reload() }
        self.observer = observer
        PHPhotoLibrary.shared().register(observer)
        observing = true
      }
      reload()
    } else {
      albums = []
    }
  }

  func openSystemLibrary() async {
    if isDemo {
      isDemo = false
      browsing = PhotoBrowseState(directory: directory, demo: false)
      authorization = .notDetermined
      albums = []
    }
    await activate(request: true)
  }

  func reload() {
    guard !isDemo, canRead else { return }
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    let fetch = PHAsset.fetchAssets(with: options)
    var all: [PhotoItem] = []
    fetch.enumerateObjects { asset, _, _ in
      if asset.mediaType == .image || asset.mediaType == .video {
        all.append(PhotoItem(asset: asset))
      }
    }
    var result = [PhotoAlbum(id: "roll", title: "Camera Roll", items: all, builtIn: true)]
    let videos = all.filter(\.isVideo)
    if !videos.isEmpty {
      result.append(PhotoAlbum(id: "videos", title: "Videos", items: videos, builtIn: true))
    }
    for subtype in [PHAssetCollectionSubtype.any] {
      let collections = PHAssetCollection.fetchAssetCollections(
        with: .album, subtype: subtype, options: nil)
      collections.enumerateObjects { collection, _, _ in
        var items: [PhotoItem] = []
        PHAsset.fetchAssets(in: collection, options: options).enumerateObjects { asset, _, _ in
          items.append(PhotoItem(asset: asset))
        }
        result.append(
          PhotoAlbum(
            id: collection.localIdentifier, title: collection.localizedTitle ?? "",
            items: items, collection: collection,
            editable: collection.assetCollectionSubtype != .albumCloudShared
              && collection.canPerform(.rename),
            shared: collection.assetCollectionSubtype == .albumCloudShared))
      }
    }
    let order = UserDefaults.standard.stringArray(forKey: "PhotosSix.albumOrder") ?? []
    albums = result.sorted {
      func rank(_ a: PhotoAlbum) -> Int {
        if a.id == "roll" { return -2 }
        if a.id == "videos" { return -1 }
        return order.firstIndex(of: a.id) ?? Int.max
      }
      return rank($0) < rank($1)
    }
  }

  func createAlbum(_ name: String) async throws -> String {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw PhotoFailure.emptyName }
    let id: String
    if isDemo {
      id = UUID().uuidString
      demoIndex.albums.append(DemoAlbum(id: id, title: title, ids: []))
      try persistDemo()
      loadDemo()
    } else {
      var created = ""
      try await PHPhotoLibrary.shared().performChanges {
        created =
          PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
          .placeholderForCreatedAssetCollection.localIdentifier
      }
      id = created
      reload()
    }
    return id
  }

  func rename(_ album: PhotoAlbum, to name: String) async throws {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw PhotoFailure.emptyName }
    if isDemo {
      if let index = demoIndex.albums.firstIndex(where: { $0.id == album.id }) {
        demoIndex.albums[index].title = title
      }
      try persistDemo()
      loadDemo()
    } else if let collection = album.collection, album.editable {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetCollectionChangeRequest(for: collection)?.title = title
      }
      reload()
    } else {
      throw PhotoFailure.save
    }
  }

  func deleteAlbum(_ album: PhotoAlbum) async throws {
    guard album.editable else { throw PhotoFailure.save }
    if isDemo {
      demoIndex.albums.removeAll { $0.id == album.id }
      try persistDemo()
      loadDemo()
    } else if let collection = album.collection {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSArray)
      }
      reload()
    }
  }

  func moveAlbum(_ album: PhotoAlbum, by offset: Int) {
    guard let from = albums.firstIndex(where: { $0.id == album.id }) else { return }
    let to = from + offset
    guard albums.indices.contains(to), albums[to].editable else { return }
    albums.swapAt(from, to)
    if isDemo {
      demoIndex.albums.sort { a, b in
        (albums.firstIndex { $0.id == a.id } ?? 0) < (albums.firstIndex { $0.id == b.id } ?? 0)
      }
      try? persistDemo()
    } else {
      UserDefaults.standard.set(albums.map(\.id), forKey: "PhotosSix.albumOrder")
    }
  }

  func add(_ items: [PhotoItem], to album: PhotoAlbum) async throws {
    guard album.editable else { throw PhotoFailure.save }
    if isDemo {
      if let index = demoIndex.albums.firstIndex(where: { $0.id == album.id }) {
        for item in items where !demoIndex.albums[index].ids.contains(item.id) {
          demoIndex.albums[index].ids.append(item.id)
        }
      }
      try persistDemo()
      loadDemo()
    } else if let collection = album.collection {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetCollectionChangeRequest(for: collection)?.addAssets(
          items.compactMap(\.asset) as NSArray)
      }
      reload()
    }
  }

  func delete(_ items: [PhotoItem], from album: PhotoAlbum? = nil) async throws {
    if isDemo {
      if let album, album.editable,
        let index = demoIndex.albums.firstIndex(where: { $0.id == album.id })
      {
        demoIndex.albums[index].ids.removeAll { id in items.contains { $0.id == id } }
      } else {
        demoIndex.deleted.formUnion(items.map(\.id))
      }
      try persistDemo()
      loadDemo()
    } else {
      try await PHPhotoLibrary.shared().performChanges {
        let assets = items.compactMap(\.asset) as NSArray
        if let collection = album?.collection, album?.editable == true {
          PHAssetCollectionChangeRequest(for: collection)?.removeAssets(assets)
        } else {
          PHAssetChangeRequest.deleteAssets(assets)
        }
      }
      reload()
    }
  }

  func savePhoto(_ data: Data) async throws {
    if isDemo {
      let file = UUID().uuidString + ".jpg"
      try data.write(to: directory.appendingPathComponent(file), options: .atomic)
      demoIndex.addedFiles.append(file)
      try persistDemo()
      loadDemo()
    } else {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
      }
      reload()
    }
  }

  func saveVideo(_ url: URL) async throws {
    if isDemo {
      let file = UUID().uuidString + ".mov"
      try FileManager.default.copyItem(at: url, to: directory.appendingPathComponent(file))
      demoIndex.addedFiles.append(file)
      try persistDemo()
      loadDemo()
    } else {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
      }
      reload()
    }
  }

  func image(_ item: PhotoItem, size: CGSize = CGSize(width: 1800, height: 1800)) async throws
    -> UIImage
  {
    if let file = item.file, !item.isVideo {
      guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
        let cg = CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
          ] as CFDictionary)
      else { throw PhotoFailure.unavailable }
      return UIImage(cgImage: cg)
    }
    if let file = item.file {
      let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = size
      return UIImage(cgImage: try await generator.image(at: .zero).image)
    }
    guard let asset = item.asset else { throw PhotoFailure.unavailable }
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true
    options.resizeMode = .fast
    return try await withCheckedThrowingContinuation { continuation in
      manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options)
      { image, info in
        if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
        if let image {
          continuation.resume(returning: image)
        } else {
          continuation.resume(throwing: PhotoFailure.unavailable)
        }
      }
    }
  }

  func videoAsset(_ item: PhotoItem) async throws -> AVAsset {
    if let file = item.file { return AVURLAsset(url: file) }
    guard let asset = item.asset else { throw PhotoFailure.unavailable }
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    return try await withCheckedThrowingContinuation { continuation in
      manager.requestAVAsset(forVideo: asset, options: options) { asset, _, info in
        if let asset {
          continuation.resume(returning: asset)
        } else {
          continuation.resume(
            throwing: (info?[PHImageErrorKey] as? Error) ?? PhotoFailure.unavailable)
        }
      }
    }
  }

  func export(_ items: [PhotoItem]) async throws -> [URL] {
    var urls: [URL] = []
    for item in items {
      if let file = item.file {
        urls.append(file)
        continue
      }
      guard let asset = item.asset else { throw PhotoFailure.unavailable }
      let resource = PHAssetResource.assetResources(for: asset)
        .first {
          item.isVideo
            ? $0.type == .video || $0.type == .fullSizeVideo
            : $0.type == .photo || $0.type == .fullSizePhoto
        }
      guard let resource else { throw PhotoFailure.unavailable }
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
        "PhotosSix-Share-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let url = folder.appendingPathComponent(resource.originalFilename)
      let options = PHAssetResourceRequestOptions()
      options.isNetworkAccessAllowed = true
      try await PHAssetResourceManager.default().writeData(
        for: resource, toFile: url, options: options)
      urls.append(url)
    }
    return urls
  }

  private func persistDemo() throws {
    try JSONEncoder().encode(demoIndex).write(
      to: directory.appendingPathComponent("index.json"), options: .atomic)
  }

  private func loadDemo() {
    #if DEBUG
      let count = ProcessInfo.processInfo.arguments.contains("--large-library") ? 6624 : 24
    #else
      let count = 24
    #endif
    var items = (0..<count).compactMap { i -> PhotoItem? in
      guard
        let file = Bundle.main.url(forResource: "Demo", withExtension: "bundle")?
          .appendingPathComponent("Scene\(i % 12).jpg")
      else { return nil }
      return PhotoItem(
        id: "demo-\(i)", date: Date(timeIntervalSince1970: 1_346_500_800 + Double(i * 6500)),
        latitude: i % 3 == 0 ? 51.24 : i % 3 == 1 ? 50.72 : 54.46,
        longitude: i % 3 == 0 ? -0.59 : i % 3 == 1 ? -1.88 : -3.08, file: file)
    }
    if let file = Bundle.main.url(forResource: "Demo", withExtension: "bundle")?
      .appendingPathComponent("DemoVideo.mov")
    {
      items.append(
        PhotoItem(
          id: "demo-video", date: Date(timeIntervalSince1970: 1_346_700_000), duration: 4,
          isVideo: true, file: file))
    }
    for file in demoIndex.addedFiles {
      let url = directory.appendingPathComponent(file)
      items.append(
        PhotoItem(
          id: file, date: .now, duration: file.hasSuffix("mov") ? 2 : 0,
          isVideo: file.hasSuffix("mov"), file: url))
    }
    items.removeAll { demoIndex.deleted.contains($0.id) }
    albums = [PhotoAlbum(id: "roll", title: "Camera Roll", items: items, builtIn: true)]
    let videos = items.filter(\.isVideo)
    if !videos.isEmpty {
      albums.append(PhotoAlbum(id: "videos", title: "Videos", items: videos, builtIn: true))
    }
    // Demo names are fixture content, translated only while creating the initial fixtures.
    if demoIndex.albums.isEmpty && demoIndex.deleted.isEmpty && demoIndex.addedFiles.isEmpty,
      !FileManager.default.fileExists(atPath: directory.appendingPathComponent("index.json").path)
    {
      demoIndex.albums = [
        DemoAlbum(id: "summer", title: L10n.text("Summer 2012"), ids: items.prefix(12).map(\.id)),
        DemoAlbum(
          id: "weekend", title: L10n.text("A Weekend Away"),
          ids: Array(items.dropFirst(12).prefix(8)).map(\.id)),
      ]
      try? persistDemo()
    }
    albums += demoIndex.albums.map { album in
      PhotoAlbum(
        id: album.id, title: album.title,
        items: album.ids.compactMap { id in items.first { $0.id == id } }, editable: true)
    }
  }
}

private final class LibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
  let changed: @MainActor () -> Void
  init(changed: @escaping @MainActor () -> Void) { self.changed = changed }
  func photoLibraryDidChange(_ changeInstance: PHChange) { Task { @MainActor in changed() } }
  deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
}
