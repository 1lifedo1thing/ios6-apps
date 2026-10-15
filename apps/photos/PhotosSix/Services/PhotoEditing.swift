import AVFoundation
import CoreImage
import UIKit

enum PhotoEditing {
  static let context = CIContext(options: [.cacheIntermediates: false])
  static func upright(_ image: UIImage) -> UIImage {
    guard let cg = image.cgImage else { return image }
    let sideways = [.left, .leftMirrored, .right, .rightMirrored].contains(image.imageOrientation)
    let size = CGSize(
      width: sideways ? cg.height : cg.width, height: sideways ? cg.width : cg.height)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  static func rotate(_ image: UIImage) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(
      size: CGSize(width: image.size.height, height: image.size.width), format: format
    ).image { renderer in
      renderer.cgContext.translateBy(x: image.size.height / 2, y: image.size.width / 2)
      renderer.cgContext.rotate(by: -.pi / 2)
      image.draw(
        in: CGRect(
          x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width,
          height: image.size.height))
    }
  }
  static func crop(_ image: UIImage, ratio: CGFloat, center: CGPoint = CGPoint(x: 0.5, y: 0.5))
    -> UIImage
  {
    guard let cg = image.cgImage else { return image }
    let width = CGFloat(cg.width)
    let height = CGFloat(cg.height)
    let target = CGSize(width: min(width, height * ratio), height: min(height, width / ratio))
    let x = max(0, min(width - target.width, center.x * width - target.width / 2))
    let y = max(0, min(height - target.height, center.y * height - target.height / 2))
    guard let cropped = cg.cropping(to: CGRect(origin: CGPoint(x: x, y: y), size: target).integral)
    else { return image }
    return UIImage(cgImage: cropped)
  }
  static func enhance(_ image: UIImage) -> UIImage {
    guard var output = CIImage(image: image) else { return image }
    for filter in output.autoAdjustmentFilters(options: [.redEye: false]) {
      filter.setValue(output, forKey: kCIInputImageKey)
      if let result = filter.outputImage { output = result }
    }
    guard let cg = context.createCGImage(output, from: output.extent) else { return image }
    return UIImage(cgImage: cg)
  }
  static func redEye(_ image: UIImage, at point: CGPoint) -> UIImage {
    guard let input = CIImage(image: image) else { return image }
    let center = CIVector(x: input.extent.width * point.x, y: input.extent.height * (1 - point.y))
    let radius = max(5, input.extent.width * 0.012)
    let mask = CIFilter(
      name: "CIRadialGradient",
      parameters: [
        "inputCenter": center,
        "inputRadius0": radius * 0.45, "inputRadius1": radius,
        "inputColor0": CIColor.white, "inputColor1": CIColor.clear,
      ])?.outputImage
    let corrected = input.applyingFilter(
      "CIColorMatrix",
      parameters: [
        "inputRVector": CIVector(x: 0, y: 0.5, z: 0.5, w: 0)
      ])
    guard let mask,
      let result = CIFilter(
        name: "CIBlendWithMask",
        parameters: [
          kCIInputImageKey: corrected, kCIInputBackgroundImageKey: input,
          kCIInputMaskImageKey: mask,
        ])?.outputImage,
      let cg = context.createCGImage(result, from: input.extent)
    else { return image }
    return UIImage(cgImage: cg)
  }
  static func trim(_ asset: AVAsset, start: Double, end: Double, output: URL) async throws {
    guard end - start >= 0.25, start >= 0,
      let session = AVAssetExportSession(
        asset: asset, presetName: AVAssetExportPresetHighestQuality)
    else { throw PhotoFailure.save }
    session.outputURL = output
    session.outputFileType = .mov
    session.timeRange = CMTimeRange(
      start: CMTime(seconds: start, preferredTimescale: 600),
      end: CMTime(seconds: end, preferredTimescale: 600))
    await session.export()
    if session.status != .completed { throw session.error ?? PhotoFailure.save }
  }
}
