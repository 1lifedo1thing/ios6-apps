import MetalKit
import SwiftUI

@MainActor final class MapPageSnapshot {
  var capture: (() -> UIImage?)?
}

struct MapPaperView: UIViewRepresentable {
  let image: UIImage
  var progress: CGFloat
  let reduceMotion: Bool
  let didClose: () -> Void

  func makeCoordinator() -> PaperRenderer { PaperRenderer(image: image) }

  func makeUIView(context: Context) -> MTKView {
    let view = MTKView(frame: .zero, device: context.coordinator.device)
    view.isOpaque = false
    view.backgroundColor = .clear
    view.clearColor = MTLClearColorMake(0, 0, 0, 0)
    view.depthStencilPixelFormat = .depth32Float
    view.sampleCount = 4
    view.isPaused = true
    view.enableSetNeedsDisplay = true
    view.delegate = context.coordinator
    view.isUserInteractionEnabled = false
    view.accessibilityElementsHidden = true
    view.isAccessibilityElement = false
    return view
  }

  func updateUIView(_ view: MTKView, context: Context) {
    context.coordinator.updateImage(image)
    context.coordinator.didClose = didClose
    context.coordinator.setTarget(Float(progress), animated: !reduceMotion, view: view)
  }
  static func dismantleUIView(_ view: MTKView, coordinator: PaperRenderer) {
    coordinator.stopAnimation()
    view.delegate = nil
  }
}

private final class PaperAnimationTarget: NSObject {
  weak var renderer: PaperRenderer?
  @objc func tick(_ link: CADisplayLink) { renderer?.tick(link) }
}

final class PaperRenderer: NSObject, MTKViewDelegate {
  let device = MTLCreateSystemDefaultDevice()
  private var progress: Float = 0
  var didClose: (() -> Void)?
  private var targetProgress: Float = -1
  private var startProgress: Float = 0
  private var startTime: CFTimeInterval = 0
  private var duration: CFTimeInterval = 0.7
  private var displayLink: CADisplayLink?
  private weak var surface: MTKView?
  private let animationTarget = PaperAnimationTarget()
  private var queue: MTLCommandQueue?
  private var pipeline: MTLRenderPipelineState?
  private var depthState: MTLDepthStencilState?
  private var texture: MTLTexture?
  private var vertices: MTLBuffer?
  private var indices: MTLBuffer?
  private var indexCount = 0
  private var sourceImage: UIImage?

  init(image: UIImage) {
    super.init()
    guard let device, let cgImage = image.cgImage else { return }
    do {
      queue = device.makeCommandQueue()
      let library = try device.makeLibrary(source: Self.shader, options: nil)
      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.vertexFunction = library.makeFunction(name: "paperVertex")
      descriptor.fragmentFunction = library.makeFunction(name: "paperFragment")
      descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
      descriptor.colorAttachments[0].isBlendingEnabled = true
      descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
      descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
      descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
      descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
      descriptor.depthAttachmentPixelFormat = .depth32Float
      descriptor.rasterSampleCount = 4
      pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
      let depth = MTLDepthStencilDescriptor()
      depth.depthCompareFunction = .lessEqual
      depth.isDepthWriteEnabled = true
      depthState = device.makeDepthStencilState(descriptor: depth)
      texture = try MTKTextureLoader(device: device).newTexture(
        cgImage: cgImage, options: [.SRGB: false, .generateMipmaps: true])
      sourceImage = image
      makeMesh(device: device)
    } catch {
      assertionFailure("Unable to initialize the paper renderer: \(error)")
    }
  }

  func setTarget(_ target: Float, animated: Bool, view: MTKView) {
    surface = view
    guard target != targetProgress else { return }
    stopAnimation()
    targetProgress = target
    startProgress = progress
    if !animated {
      progress = target
      view.setNeedsDisplay()
      if target == 0 { DispatchQueue.main.async { [weak self] in self?.didClose?() } }
      return
    }
    startTime = CACurrentMediaTime()
    duration = max(0.14, 0.7 * Double(abs(target - progress)))
    animationTarget.renderer = self
    let link = CADisplayLink(
      target: animationTarget, selector: #selector(PaperAnimationTarget.tick(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  fileprivate func tick(_ link: CADisplayLink) {
    let fraction = Float(min(1, max(0, (link.timestamp - startTime) / duration)))
    let eased = fraction * fraction * (3 - 2 * fraction)
    progress = startProgress + (targetProgress - startProgress) * eased
    surface?.setNeedsDisplay()
    if fraction >= 1 {
      stopAnimation()
      if targetProgress == 0 { didClose?() }
    }
  }

  func stopAnimation() {
    displayLink?.invalidate()
    displayLink = nil
  }

  func updateImage(_ image: UIImage) {
    guard image !== sourceImage, let device, let cgImage = image.cgImage else { return }
    if let replacement = try? MTKTextureLoader(device: device).newTexture(
      cgImage: cgImage, options: [.SRGB: false, .generateMipmaps: true])
    {
      texture = replacement
      sourceImage = image
    }
  }

  private func makeMesh(device: MTLDevice) {
    let columns = 80
    let rows = 180
    var points: [SIMD2<Float>] = []
    var triangles: [UInt32] = []
    for row in 0...rows {
      for column in 0...columns {
        points.append(SIMD2(Float(column) / Float(columns), Float(row) / Float(rows)))
      }
    }
    for row in 0..<rows {
      for column in 0..<columns {
        let a = UInt32(row * (columns + 1) + column)
        let b = a + 1
        let c = a + UInt32(columns + 1)
        triangles += [a, b, c, b, c + 1, c]
      }
    }
    vertices = device.makeBuffer(
      bytes: points, length: points.count * MemoryLayout<SIMD2<Float>>.stride)
    indices = device.makeBuffer(
      bytes: triangles, length: triangles.count * MemoryLayout<UInt32>.stride)
    indexCount = triangles.count
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { view.setNeedsDisplay() }

  func draw(in view: MTKView) {
    guard let pipeline, let vertices, let indices, let texture,
      let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
      let command = queue?.makeCommandBuffer(),
      let encoder = command.makeRenderCommandEncoder(descriptor: pass)
    else { return }
    encoder.setRenderPipelineState(pipeline)
    encoder.setDepthStencilState(depthState)
    encoder.setFrontFacing(.clockwise)
    encoder.setCullMode(.none)
    encoder.setVertexBuffer(vertices, offset: 0, index: 0)
    encoder.setFragmentTexture(texture, index: 0)
    var uniforms = SIMD4<Float>(Float(view.bounds.width), Float(view.bounds.height), progress, 0)
    for layer in 0...1 {
      uniforms.w = Float(layer)
      encoder.setVertexBytes(&uniforms, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
      encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
      encoder.drawIndexedPrimitives(
        type: .triangle, indexCount: indexCount, indexType: .uint32,
        indexBuffer: indices, indexBufferOffset: 0)
    }
    encoder.endEncoding()
    command.present(drawable)
    command.commit()
  }

  // A cylindrical bend keeps the map continuous through the roll and onto the paper back.
  private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct PaperVertex {
      float4 position [[position]];
      float2 uv;
      float3 normal;
      float distance;
    };
    vertex PaperVertex paperVertex(uint id [[vertex_id]],
      constant float2 *vertices [[buffer(0)]], constant float4 &u [[buffer(1)]]) {
      float2 uv = vertices[id];
      float2 p = uv * u.xy;
      float progress = clamp(u.z, 0.0, 1.0);
      float tilt = mix(0.8, 0.18, progress);
      float2 n = normalize(float2(tilt, 1));
      float fullRadius = u.x * 0.238;
      // Leave twelve points between the roll and the 270-point options region.
      float depth = u.y < 450 ? u.y + u.x * 0.3 + 120 : 282 + fullRadius;
      float crease = u.y + 24 - (depth + 24) * progress;
      float d = dot(p - float2(0, crease), n);
      float radius = mix(10.0, fullRadius, progress);
      float phi = clamp(d / radius, 0.0, M_PI_F);
      float z = 0;
      float3 normal = float3(0, 0, 1);
      if (u.w > 0.5 && d > 0) {
        float rolled = radius * sin(phi) - max(0.0, d - M_PI_F * radius);
        p += n * (rolled - d);
        z = radius * (1 - cos(phi));
        normal = float3(-n * sin(phi), cos(phi));
      }
      PaperVertex out;
      out.position = float4(p.x / u.x * 2 - 1, 1 - p.y / u.y * 2,
        u.w < 0.5 ? 0.99 : 0.8 - z / 500, 1);
      out.uv = uv;
      out.normal = normal;
      out.distance = d;
      return out;
    }
    fragment float4 paperFragment(PaperVertex in [[stage_in]], bool front [[front_facing]],
      texture2d<float> map [[texture(0)]], constant float4 &u [[buffer(1)]]) {
      if (u.w < 0.5) {
        float shadow = exp(-abs(in.distance - 13) / 20.0) * 0.55 * u.z;
        return float4(0, 0, 0, shadow);
      }
      constexpr sampler sample(filter::linear, mip_filter::linear, address::clamp_to_edge);
      float3 ink = map.sample(sample, in.uv).rgb;
      float3 normal = normalize(front ? in.normal : -in.normal);
      float light = 0.56 + 0.44 * max(0.0, dot(normal, normalize(float3(-0.25, -0.4, 1))));
      float3 color = front ? ink * (1 - 0.18 * u.z) : mix(float3(1, 0.998, 0.975), ink, 0.08);
      return float4(color * light, 1);
    }
    """
}
