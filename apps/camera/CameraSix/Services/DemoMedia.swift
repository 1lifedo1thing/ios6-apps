import AVFoundation
import UIKit

enum DemoMedia {
  static func video(image: UIImage, duration: TimeInterval) async throws -> URL {
    try await Task.detached(priority: .userInitiated) {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString + ".mov")
      let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
      let input = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
          AVVideoCodecKey: AVVideoCodecType.h264,
          AVVideoWidthKey: 480, AVVideoHeightKey: 640,
        ])
      let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
          kCVPixelBufferWidthKey as String: 480, kCVPixelBufferHeightKey as String: 640,
        ])
      writer.add(input)
      guard writer.startWriting() else { throw writer.error ?? ImageProcessingError.invalidImage }
      writer.startSession(atSourceTime: .zero)
      for frame in 0..<Int(duration * 12) {
        while !input.isReadyForMoreMediaData {
          guard writer.status == .writing else {
            throw writer.error ?? ImageProcessingError.invalidImage
          }
          try await Task.sleep(for: .milliseconds(10))
        }
        var buffer: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool,
          CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer
        else {
          throw ImageProcessingError.invalidImage
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let context = CGContext(
          data: CVPixelBufferGetBaseAddress(buffer), width: 480, height: 640,
          bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        {
          context.translateBy(x: 0, y: 640)
          context.scaleBy(x: 1, y: -1)
          UIGraphicsPushContext(context)
          image.draw(in: CGRect(x: -CGFloat(frame % 12), y: 0, width: 492, height: 656))
          UIGraphicsPopContext()
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard
          adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 12))
        else {
          throw writer.error ?? ImageProcessingError.invalidImage
        }
      }
      input.markAsFinished()
      await writer.finishWriting()
      guard writer.status == .completed else {
        throw writer.error ?? ImageProcessingError.invalidImage
      }
      return url
    }.value
  }
}
