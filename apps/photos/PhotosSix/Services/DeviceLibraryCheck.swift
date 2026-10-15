#if DEBUG
  import AVFoundation
  import Foundation

  // A signed-device check avoids installing an additional XCTest runner on free profiles.
  // It reads authorized media and writes only an aggregate report to the app's Documents.
  @MainActor enum DeviceLibraryCheck {
    static func run(_ library: PhotoLibrary) async -> String? {
      var report: [String: Any] = [
        "platform": "physical", "demo": library.isDemo,
        "authorized": library.canRead, "itemCount": library.allItems.count,
        "albumCount": library.albums.count,
      ]
      let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DeviceVerification", isDirectory: true)
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      var firstID: String?
      do {
        guard library.canRead, !library.isDemo else { throw PhotoFailure.permission }
        if let photo = library.allItems.first(where: { !$0.isVideo }) {
          let image = try await library.image(photo, size: CGSize(width: 1024, height: 1024))
          report["photoDecode"] = image.size.width > 0 && image.size.height > 0
          let rotated = PhotoEditing.rotate(image)
          let cropped = PhotoEditing.crop(rotated, ratio: 1)
          let enhanced = PhotoEditing.enhance(cropped)
          report["photoEditJPEG"] = enhanced.jpegData(compressionQuality: 0.9)?.isEmpty == false
          firstID = photo.id
        }
        let candidates = library.allItems.reversed().filter {
          $0.isVideo && $0.duration >= 1 && $0.duration < 10
        }.prefix(5)
        for video in candidates {
          do {
            let asset = try await library.videoAsset(video)
            let duration = try await asset.load(.duration).seconds
            let url = directory.appendingPathComponent("trim-check.mov")
            defer { try? FileManager.default.removeItem(at: url) }
            try? FileManager.default.removeItem(at: url)
            try await PhotoEditing.trim(asset, start: 0, end: min(1, duration), output: url)
            let trimmed = try await AVURLAsset(url: url).load(.duration).seconds
            report["videoTrim"] = abs(trimmed - min(1, duration)) < 0.15
            break
          } catch { report["videoAvailabilityNote"] = error.localizedDescription }
        }
        report["passed"] =
          (report["photoDecode"] as? Bool == true) && (report["photoEditJPEG"] as? Bool == true)
      } catch {
        report["error"] = error.localizedDescription
        report["passed"] = false
      }
      if let data = try? JSONSerialization.data(
        withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
      {
        try? data.write(to: directory.appendingPathComponent("report.json"), options: .atomic)
      }
      return firstID
    }
  }
#endif
