import AVFoundation
import UIKit
import XCTest

@testable import PhotosSix

final class PhotosSixTests: XCTestCase {
  @MainActor func testBrowsePositionsPersistPerAlbumAndRecoverDeletedAnchors() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let items = (0..<6625).map {
      PhotoItem(id: "item-\($0)", date: Date(timeIntervalSince1970: Double($0)), file: nil)
    }
    let state = PhotoBrowseState(directory: directory, demo: false)
    XCTAssertEqual(state.anchor(in: items, albumID: "roll", latest: true), "item-6624")
    state.remember(items[4000], albumID: "roll")
    state.remember(items[18], albumID: "trip")
    state.save()
    let restored = PhotoBrowseState(directory: directory, demo: false)
    XCTAssertEqual(restored.anchor(in: items, albumID: "roll", latest: true), "item-4000")
    XCTAssertEqual(restored.anchor(in: items, albumID: "trip", latest: false), "item-18")
    let deleted = items.filter { $0.id != "item-4000" }
    XCTAssertEqual(restored.anchor(in: deleted, albumID: "roll", latest: true), "item-4001")
    XCTAssertEqual(
      restored.anchor(in: Array(items.prefix(20)), albumID: "roll", latest: true), "item-19")
    XCTAssertNil(restored.anchor(in: [], albumID: "roll", latest: true))
    XCTAssertEqual(
      PhotoBrowseState(directory: directory, demo: true).anchor(
        in: items, albumID: "roll", latest: true), "item-6624")
  }

  func testLanguageVariantsAndFallback() {
    for language in ["zh", "zh-Hant-TW", "zh-HK", "ZH-cn", "zh-Hans"] {
      XCTAssertEqual(AppLanguage.preferred([language]), .chinese)
    }
    for languages in [[], ["en-GB"], ["fr-FR", "zh"], ["ja"]] {
      XCTAssertEqual(AppLanguage.preferred(languages), .english)
    }
    XCTAssertEqual(L10n.text("Camera Roll", language: .chinese), "相机胶卷")
    XCTAssertEqual(L10n.format("%d of %d", 2, 5, language: .chinese), "第 2 个，共 5 个")
    XCTAssertEqual(
      PhotoLink.assetID(from: URL(string: "photossix://library?asset=ABC%2F001")!), "ABC/001")
    XCTAssertNil(PhotoLink.assetID(from: URL(string: "https://library?asset=ABC")!))
  }

  @MainActor func testAlbumPersistenceDeletionAndOriginalPreservation() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let library = PhotoLibrary(demo: true, directory: directory)
    XCTAssertEqual(library.allItems.count, 25)
    let item = try XCTUnwrap(library.allItems.first)
    let id = try await library.createAlbum("  My trip  ")
    var album = try XCTUnwrap(library.albums.first { $0.id == id })
    try await library.add([item, item], to: album)
    album = try XCTUnwrap(library.albums.first { $0.id == id })
    XCTAssertEqual(album.items.count, 1)
    try await library.rename(album, to: "Updated")
    let reopened = PhotoLibrary(demo: true, directory: directory)
    album = try XCTUnwrap(reopened.albums.first { $0.id == id })
    XCTAssertEqual(album.title, "Updated")
    try await reopened.delete([item], from: album)
    XCTAssertEqual(reopened.allItems.count, 25)
    XCTAssertEqual(reopened.albums.first { $0.id == id }?.items.count, 0)
    try await reopened.deleteAlbum(album)
    XCTAssertEqual(reopened.allItems.count, 25)
    XCTAssertFalse(reopened.albums.contains { $0.id == id })
    do {
      _ = try await reopened.createAlbum("  ")
      XCTFail("Empty name accepted")
    } catch PhotoFailure.emptyName {}
    try await reopened.delete([item])
    XCTAssertEqual(PhotoLibrary(demo: true, directory: directory).allItems.count, 24)
    XCTAssertTrue(FileManager.default.fileExists(atPath: item.file!.path))
  }

  @MainActor func testEditingProducesRealJPEGAndPreservesOriginal() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let library = PhotoLibrary(demo: true, directory: directory)
    let item = try XCTUnwrap(library.allItems.first)
    let before = try Data(contentsOf: item.file!)
    let image = try await library.image(item)
    let rotated = PhotoEditing.rotate(image)
    XCTAssertEqual(rotated.size.width, image.size.height)
    let cropped = PhotoEditing.crop(rotated, ratio: 1, center: CGPoint(x: 0.8, y: 0.6))
    XCTAssertEqual(cropped.size.width, cropped.size.height)
    let enhanced = PhotoEditing.enhance(cropped)
    let corrected = PhotoEditing.redEye(enhanced, at: CGPoint(x: 0.5, y: 0.5))
    let data = try XCTUnwrap(corrected.jpegData(compressionQuality: 0.95))
    try await library.savePhoto(data)
    XCTAssertEqual(library.allItems.count, 26)
    XCTAssertEqual(before, try Data(contentsOf: item.file!))
    let new = try XCTUnwrap(library.allItems.last)
    XCTAssertNotNil(UIImage(contentsOfFile: new.file!.path))
    XCTAssertEqual(PhotoLibrary(demo: true, directory: directory).allItems.count, 26)
  }

  @MainActor func testVideoPlaybackExportAndTrimming() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let library = PhotoLibrary(demo: true, directory: directory)
    let video = try XCTUnwrap(library.allItems.first(where: \.isVideo))
    let asset = try await library.videoAsset(video)
    let duration = try await asset.load(.duration).seconds
    XCTAssertEqual(duration, 4, accuracy: 0.1)
    let output = directory.appendingPathComponent("trim.mov")
    try await PhotoEditing.trim(asset, start: 1, end: 2.5, output: output)
    let trimmed = try await AVURLAsset(url: output).load(.duration).seconds
    XCTAssertEqual(trimmed, 1.5, accuracy: 0.1)
    try await library.saveVideo(output)
    XCTAssertEqual(library.allItems.filter(\.isVideo).count, 2)
    let urls = try await library.export([video])
    XCTAssertEqual(urls, [video.file!])
    let originalDuration = try await asset.load(.duration).seconds
    XCTAssertEqual(originalDuration, 4, accuracy: 0.1)
  }

  func testPortraitOrientationIsNormalizedBeforeEditing() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let source = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40), format: format).image
    { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 80, height: 20))
      UIColor.blue.setFill()
      context.fill(CGRect(x: 0, y: 20, width: 80, height: 20))
    }
    let portrait = UIImage(cgImage: try XCTUnwrap(source.cgImage), scale: 1, orientation: .right)
    let normalized = PhotoEditing.upright(portrait)
    XCTAssertEqual(normalized.imageOrientation, .up)
    XCTAssertEqual(normalized.size, CGSize(width: 40, height: 80))
    let square = PhotoEditing.crop(normalized, ratio: 1)
    XCTAssertEqual(square.size, CGSize(width: 40, height: 40))
    XCTAssertNotNil(square.jpegData(compressionQuality: 0.95))
  }

  @MainActor func testLocationGroupingAndReordering() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let library = PhotoLibrary(demo: true, directory: directory)
    XCTAssertEqual(PlaceCluster.clusters(library.allItems).count, 3)
    XCTAssertEqual(PlaceCluster.clusters(library.allItems).flatMap(\.items).count, 24)
    let before = library.albums.filter(\.editable).map(\.id)
    library.moveAlbum(library.albums.last!, by: -1)
    XCTAssertEqual(library.albums.filter(\.editable).map(\.id), before.reversed())
    XCTAssertEqual(
      PhotoLibrary(demo: true, directory: directory).albums.filter(\.editable).map(\.id),
      before.reversed())
  }
}
