import CoreImage
import UIKit
import Vision

enum ImageProcessingError: Error {
  case invalidImage, insufficientFrames, alignmentFailed
}

enum ImageProcessing {
  static let context = CIContext(options: [.cacheIntermediates: false])

  static func upright(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
    let scale = min(1, maxDimension / max(image.size.width, image.size.height))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  static func aligned(_ image: CGImage, to reference: CGImage) throws -> CGImage {
    let request = VNTranslationalImageRegistrationRequest(targetedCGImage: image)
    try VNImageRequestHandler(cgImage: reference).perform([request])
    guard let transform = request.results?.first?.alignmentTransform else {
      throw ImageProcessingError.alignmentFailed
    }
    let extent = CGRect(x: 0, y: 0, width: reference.width, height: reference.height)
    let output = CIImage(cgImage: image).transformed(by: transform).clampedToExtent()
    guard let cgImage = context.createCGImage(output, from: extent) else {
      throw ImageProcessingError.invalidImage
    }
    return cgImage
  }

  // Exposure fusion favors well-exposed pixels instead of averaging clipped highlights and shadows.
  static func fuseExposures(_ data: [Data]) throws -> Data {
    let images = data.compactMap(UIImage.init(data:)).map { upright($0) }.compactMap(\.cgImage)
    guard images.count >= 3 else { throw ImageProcessingError.invalidImage }
    let reference = images[1]
    let alignedImages = images.enumerated().map { index, image in
      index == 1 ? image : (try? aligned(image, to: reference)) ?? image
    }
    let width = reference.width
    let height = reference.height
    let count = width * height * 4
    let buffers: [[UInt8]] = alignedImages.map { image in
      var bytes = [UInt8](repeating: 0, count: count)
      bytes.withUnsafeMutableBytes { raw in
        let ctx = CGContext(
          data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      }
      return bytes
    }
    var output = [UInt8](repeating: 255, count: count)
    for offset in stride(from: 0, to: count, by: 4) {
      var weights = [Double]()
      for buffer in buffers {
        let luminance =
          (Double(buffer[offset]) * 0.2126 + Double(buffer[offset + 1]) * 0.7152
            + Double(buffer[offset + 2]) * 0.0722) / 255
        weights.append(max(0.002, pow(max(0, 1 - abs(luminance - 0.5) * 2), 4)))
      }
      let total = weights.reduce(0, +)
      for channel in 0..<3 {
        let value = zip(buffers, weights).reduce(0.0) { $0 + Double($1.0[offset + channel]) * $1.1 }
        output[offset + channel] = UInt8(min(255, max(0, value / total)))
      }
    }
    let result: CGImage? = output.withUnsafeMutableBytes { raw in
      CGContext(
        data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
    }
    guard let result, let jpeg = UIImage(cgImage: result).jpegData(compressionQuality: 0.94) else {
      throw ImageProcessingError.invalidImage
    }
    return jpeg
  }
}

// Bounded, feathered mosaics of overlapping camera frames. Vision supplies measured image alignment.
final class PanoramaBuilder {
  private var frames: [(image: UIImage, origin: CGPoint)] = []
  private var previous: CGImage?
  private var origin = CGPoint.zero

  var count: Int { frames.count }

  func append(_ image: UIImage) throws {
    guard frames.count < 30 else { return }
    let normalized = ImageProcessing.upright(image, maxDimension: 960)
    guard let cgImage = normalized.cgImage else { throw ImageProcessingError.invalidImage }
    if let previous {
      let request = VNTranslationalImageRegistrationRequest(targetedCGImage: cgImage)
      try VNImageRequestHandler(cgImage: previous).perform([request])
      guard let transform = request.results?.first?.alignmentTransform,
        abs(transform.tx) < CGFloat(cgImage.width) * 0.8,
        abs(transform.ty) < CGFloat(cgImage.height) * 0.2
      else { throw ImageProcessingError.alignmentFailed }
      if abs(transform.tx) < 8 { return }
      // Vision coordinates have an upward Y axis, unlike UIKit drawing coordinates.
      origin.x += transform.tx
      origin.y -= transform.ty
    }
    frames.append((normalized, origin))
    previous = cgImage
  }

  func finish() throws -> Data {
    guard frames.count >= 2 else { throw ImageProcessingError.insufficientFrames }
    let size = frames[0].image.size
    let minX = frames.map(\.origin.x).min() ?? 0
    let maxX = frames.map(\.origin.x).max() ?? 0
    let cropTop = frames.map(\.origin.y).max() ?? 0
    let cropBottom = frames.map { $0.origin.y + size.height }.min() ?? size.height
    let canvas = CGSize(width: maxX - minX + size.width, height: cropBottom - cropTop)
    guard canvas.width > size.width + 8, canvas.width <= 16000, canvas.height > size.height * 0.6
    else {
      throw ImageProcessingError.alignmentFailed
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let image = UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
      UIColor.black.setFill()
      renderer.fill(CGRect(origin: .zero, size: canvas))
      for (index, frame) in frames.enumerated() {
        let rect = CGRect(
          x: frame.origin.x - minX, y: frame.origin.y - cropTop,
          width: size.width, height: size.height)
        renderer.cgContext.saveGState()
        if index > 0 {
          // Feather 64 pixels at the entering edge, then replace the remaining frame.
          let rightward = frame.origin.x >= frames[index - 1].origin.x
          let edge = rightward ? rect.minX : rect.maxX
          let fade = CGRect(x: rightward ? edge : edge - 64, y: 0, width: 64, height: canvas.height)
          renderer.cgContext.clip(to: fade)
          for step in 0..<16 {
            let strip = CGRect(
              x: fade.minX + CGFloat(step) * 4, y: 0, width: 4, height: canvas.height)
            renderer.cgContext.saveGState()
            renderer.cgContext.clip(to: strip)
            frame.image.draw(
              in: rect, blendMode: .normal,
              alpha: CGFloat(rightward ? step + 1 : 16 - step) / 16)
            renderer.cgContext.restoreGState()
          }
          renderer.cgContext.restoreGState()
          renderer.cgContext.saveGState()
          let solid = CGRect(
            x: rightward ? rect.minX + 64 : rect.minX, y: 0,
            width: size.width - 64, height: canvas.height)
          renderer.cgContext.clip(to: solid)
        }
        frame.image.draw(in: rect)
        renderer.cgContext.restoreGState()
      }
    }
    guard let data = image.jpegData(compressionQuality: 0.94) else {
      throw ImageProcessingError.invalidImage
    }
    return data
  }
}
