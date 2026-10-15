import AppKit
import AVFoundation
import CoreVideo

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let output = directory.appendingPathComponent("DemoVideo.mov")
try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 640, AVVideoHeightKey: 480])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 640, kCVPixelBufferHeightKey as String: 480])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
let image = NSImage(contentsOf: directory.appendingPathComponent("Scene0.jpg"))!
var rect = CGRect(x: 0, y: 0, width: 640, height: 480)
let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
for index in 0..<120 {
  while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
  var buffer: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
  let pixel = buffer!
  CVPixelBufferLockBaseAddress(pixel, [])
  let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
  let scale = 1 + Double(index) / 2400
  context.draw(cgImage, in: CGRect(x: -Double(index) / 10, y: 0, width: 640 * scale, height: 480 * scale))
  CVPixelBufferUnlockBaseAddress(pixel, [])
  adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(index), timescale: 30))
}
input.markAsFinished()
let semaphore = DispatchSemaphore(value: 0)
writer.finishWriting { semaphore.signal() }; semaphore.wait()
guard writer.status == .completed else { fatalError(writer.error!.localizedDescription) }
print(output.path)
