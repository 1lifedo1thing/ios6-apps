import Photos
import XCTest

@testable import PhotosSix

final class PhotosSystemLibraryTests: XCTestCase {
  @MainActor func testPhotoKitAlbumChangesPreserveSystemAsset() async throws {
    #if !targetEnvironment(simulator)
      throw XCTSkip("Use only with the isolated simulator system library.")
    #endif
    guard ProcessInfo.processInfo.environment["RUN_SYSTEM_LIBRARY_TESTS"] == "1" else {
      throw XCTSkip(
        "Opt in after preparing a simulator library with the CameraSix integration test.")
    }
    guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
      throw XCTSkip("Grant full Photos access on the test simulator first.")
    }
    let library = PhotoLibrary(demo: false)
    await library.activate()
    let originalCount = library.allItems.count
    let item = try XCTUnwrap(library.allItems.first)
    let id = try await library.createAlbum("PhotosSix Verification " + UUID().uuidString)
    var album = try XCTUnwrap(library.albums.first { $0.id == id })
    XCTAssertTrue(album.editable)
    try await library.rename(album, to: "PhotosSix Renamed Verification")
    album = try XCTUnwrap(library.albums.first { $0.id == id })
    XCTAssertEqual(album.title, "PhotosSix Renamed Verification")
    try await library.add([item], to: album)
    XCTAssertEqual(library.albums.first { $0.id == id }?.items.first?.id, item.id)
    try await library.delete([item], from: album)
    XCTAssertTrue(library.albums.first { $0.id == id }?.items.isEmpty == true)
    XCTAssertEqual(library.allItems.count, originalCount)
    try await library.deleteAlbum(album)
    XCTAssertFalse(library.albums.contains { $0.id == id })
    XCTAssertEqual(library.allItems.count, originalCount)
  }
}
