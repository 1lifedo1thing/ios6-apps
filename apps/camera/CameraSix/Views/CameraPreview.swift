import AVFoundation
import AVKit
import SwiftUI

struct CameraPreview: UIViewRepresentable {
  @ObservedObject var camera: CameraStore
  let onFocus: (CGPoint, Bool) -> Void

  func makeUIView(context: Context) -> PreviewSurface {
    let view = PreviewSurface()
    view.previewLayer.session = camera.isDemo ? nil : camera.engine.session
    view.previewLayer.videoGravity = .resizeAspectFill
    view.onFocus = { devicePoint, localPoint, locked in
      camera.focus(devicePoint, locked: locked)
      onFocus(localPoint, locked)
    }
    view.onZoom = { camera.setZoom($0) }
    view.onRotation = { camera.engine.setRotation($0) }
    view.capture = { camera.shutter() }
    view.onRoll = {
      if camera.canCapture && camera.mode != .panorama { camera.showRoll = true }
    }
    return view
  }

  func updateUIView(_ view: PreviewSurface, context: Context) {
    view.zoom = camera.zoom
    view.canZoom = camera.mode != .panorama
    view.hardwareEnabled = camera.canCapture && !camera.isDemo
    view.isUserInteractionEnabled = !camera.isSwitchingCamera
    view.accessibilityLabel = L10n.text(
      "Viewfinder. Tap to focus, hold to lock focus, pinch to zoom.")
    view.accessibilityIdentifier = "viewfinder"
  }
}

final class PreviewSurface: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  var onFocus: ((CGPoint, CGPoint, Bool) -> Void)?
  var onZoom: ((CGFloat) -> Void)?
  var onRotation: ((CGFloat) -> Void)?
  var capture: (() -> Void)?
  var onRoll: (() -> Void)?
  var zoom: CGFloat = 1
  var canZoom = true
  private var initialZoom: CGFloat = 1
  private var rotation: CGFloat = -1
  private var captureInteraction: AnyObject?
  var hardwareEnabled = false {
    didSet {
      if #available(iOS 17.2, *), let interaction = captureInteraction as? AVCaptureEventInteraction
      {
        interaction.isEnabled = hardwareEnabled
      }
    }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isAccessibilityElement = true
    accessibilityTraits = [.allowsDirectInteraction]
    let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
    let hold = UILongPressGestureRecognizer(target: self, action: #selector(held))
    hold.minimumPressDuration = 0.6
    tap.require(toFail: hold)
    addGestureRecognizer(tap)
    addGestureRecognizer(hold)
    addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinched)))
    let rollSwipe = UISwipeGestureRecognizer(target: self, action: #selector(showRoll))
    rollSwipe.direction = .right
    addGestureRecognizer(rollSwipe)
    if #available(iOS 17.2, *) {
      let interaction = AVCaptureEventInteraction { [weak self] event in
        if event.phase == .ended { self?.capture?() }
      }
      interaction.isEnabled = false
      addInteraction(interaction)
      captureInteraction = interaction
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    let angle: CGFloat
    switch window?.windowScene?.interfaceOrientation {
    case .landscapeLeft: angle = 180
    case .landscapeRight: angle = 0
    case .portraitUpsideDown: angle = 270
    default: angle = 90
    }
    guard angle != rotation else { return }
    rotation = angle
    if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
      connection.videoRotationAngle = angle
    }
    onRotation?(angle)
  }

  @objc private func tapped(_ gesture: UITapGestureRecognizer) {
    focus(gesture.location(in: self), locked: false)
  }
  @objc private func showRoll() { onRoll?() }
  @objc private func held(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began { focus(gesture.location(in: self), locked: true) }
  }
  private func focus(_ point: CGPoint, locked: Bool) {
    let devicePoint =
      previewLayer.session == nil
      ? CGPoint(
        x: point.x / max(1, bounds.width),
        y: point.y / max(1, bounds.height))
      : previewLayer.captureDevicePointConverted(fromLayerPoint: point)
    onFocus?(devicePoint, point, locked)
  }
  @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
    guard canZoom else { return }
    if gesture.state == .began { initialZoom = zoom }
    onZoom?(initialZoom * gesture.scale)
  }
}
