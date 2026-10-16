import MapKit
import SwiftUI

struct ClassicMapView: UIViewRepresentable {
  let store: MapsStore
  var pageSnapshot: MapPageSnapshot?
  var contentInsets = UIEdgeInsets.zero
  var interactive = true
  var fold: MapFoldGeometry?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeCoordinator() -> Coordinator { Coordinator(store: store) }
  func makeUIView(context: Context) -> MKMapView {
    let map = FoldedMapView()
    map.delegate = context.coordinator
    map.setRegion(store.region, animated: false)
    map.showsCompass = true
    map.showsScale = true
    map.showsBuildings = true
    map.pointOfInterestFilter = .includingAll
    map.accessibilityIdentifier = "classic-map"
    let press = UILongPressGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.longPress(_:)))
    map.addGestureRecognizer(press)
    return map
  }
  func updateUIView(_ map: MKMapView, context: Context) {
    (map as? FoldedMapView)?.fold = fold
    map.isUserInteractionEnabled = interactive
    map.accessibilityElementsHidden = !interactive
    map.insetsLayoutMarginsFromSafeArea = false
    map.layoutMargins = UIEdgeInsets(
      top: contentInsets.top, left: contentInsets.left, bottom: contentInsets.bottom + 58,
      right: contentInsets.right)
    pageSnapshot?.capture = { [weak map] in
      guard let map, map.bounds.width > 0, map.bounds.height > 0 else { return nil }
      let pageBounds = map.bounds.inset(
        by: UIEdgeInsets(
          top: contentInsets.top, left: contentInsets.left, bottom: 0,
          right: contentInsets.right))
      guard pageBounds.width > 0, pageBounds.height > 0 else { return nil }
      let format = UIGraphicsImageRendererFormat()
      format.preferredRange = .standard
      format.opaque = true
      let visibleMask = map.layer.mask
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      map.layer.mask = nil
      CATransaction.commit()
      // Commit the unmasked layer tree before UIKit captures the page texture.
      CATransaction.flush()
      defer {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        map.layer.mask = visibleMask
        CATransaction.commit()
      }
      return UIGraphicsImageRenderer(bounds: pageBounds, format: format).image { _ in
        map.drawHierarchy(in: map.bounds, afterScreenUpdates: true)
      }
    }
    let coordinator = context.coordinator
    coordinator.store = store
    coordinator.reduceMotion = reduceMotion
    let type = store.style.type(threeD: store.threeD)
    if map.mapType != type { map.mapType = type }
    map.showsTraffic = store.traffic
    let authorized = [.authorizedAlways, .authorizedWhenInUse].contains(
      store.location.authorization)
    map.showsUserLocation = authorized
    let ids = store.results.map(\.id)
    if coordinator.ids != ids {
      coordinator.ids = ids
      map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
      map.addAnnotations(store.results.map(PlaceAnnotation.init))
    }
    let key = "\(store.routeRevision)-\(store.routeIndex)"
    if coordinator.routeKey != key {
      coordinator.routeKey = key
      map.removeOverlays(map.overlays)
      if let route = store.route {
        map.addOverlay(route.polyline, level: .aboveRoads)
        map.setVisibleMapRect(
          route.polyline.boundingMapRect,
          edgePadding: UIEdgeInsets(top: 100, left: 40, bottom: 110, right: 40),
          animated: !reduceMotion)
      }
    }
    if coordinator.cameraRevision != store.cameraRevision || coordinator.threeD != store.threeD {
      let was3D = coordinator.threeD
      coordinator.cameraRevision = store.cameraRevision
      coordinator.threeD = store.threeD
      let center = store.cameraTarget ?? map.centerCoordinate
      let baseDistance =
        store.navigating
        ? 700.0 : (was3D != store.threeD ? max(600, map.camera.centerCoordinateDistance) : 2200)
      let distance =
        store.follow
        ? max(baseDistance, min(400_000, (store.location.location?.horizontalAccuracy ?? 0) * 4))
        : baseDistance
      let heading =
        store.navigating && store.follow
        ? max(0, store.location.location?.course ?? 0) : map.camera.heading
      map.setCamera(
        MKMapCamera(
          lookingAtCenter: center, fromDistance: distance, pitch: store.threeD ? 58 : 0,
          heading: heading), animated: !reduceMotion)
    }
    if coordinator.flyover != store.flyover {
      coordinator.flyover = store.flyover
      if store.flyover {
        let camera = map.camera.copy() as! MKMapCamera
        camera.heading += 90
        map.setCamera(camera, animated: !reduceMotion)
      }
    }
    if let selected = store.selected,
      let annotation = map.annotations.first(where: {
        ($0 as? PlaceAnnotation)?.place.id == selected.id
      }),
      !map.selectedAnnotations.contains(where: { ($0 as? PlaceAnnotation)?.place.id == selected.id }
      )
    {
      map.selectAnnotation(annotation, animated: !reduceMotion)
    }
  }
  static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
    map.delegate = nil
    map.showsUserLocation = false
  }

  @MainActor final class Coordinator: NSObject, MKMapViewDelegate {
    var store: MapsStore
    var ids: [String] = []
    var routeKey = ""
    var cameraRevision = 0
    var threeD = false
    var flyover = false
    var reduceMotion = false
    init(store: MapsStore) { self.store = store }
    @objc func longPress(_ gesture: UILongPressGestureRecognizer) {
      guard gesture.state == .began, let map = gesture.view as? MKMapView else { return }
      store.dropPin(map.convert(gesture.location(in: map), toCoordinateFrom: map))
    }
    func mapView(_ map: MKMapView, regionDidChangeAnimated animated: Bool) {
      store.region = map.region
    }
    func mapView(_ map: MKMapView, regionWillChangeAnimated animated: Bool) {
      if map.subviews.contains(where: {
        $0.gestureRecognizers?.contains(where: { $0.state == .began || $0.state == .changed })
          == true
      }) {
        store.follow = false
      }
    }
    func mapView(_ map: MKMapView, didSelect view: MKAnnotationView) {
      guard let annotation = view.annotation as? PlaceAnnotation else { return }
      store.selected = annotation.place
    }
    func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
      guard let annotation = annotation as? PlaceAnnotation else { return nil }
      let view =
        map.dequeueReusableAnnotationView(withIdentifier: "classic-pin")
        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "classic-pin")
      view.annotation = annotation
      view.image = UIImage(named: "RedPin")
      view.centerOffset = CGPoint(x: 7, y: -20)
      view.canShowCallout = false
      view.isAccessibilityElement = true
      view.accessibilityLabel = annotation.place.title()
      return view
    }
    func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
      guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
      let renderer = MKPolylineRenderer(polyline: line)
      renderer.strokeColor = UIColor(red: 0.13, green: 0.4, blue: 0.93, alpha: 0.85)
      renderer.lineWidth = 7
      renderer.lineJoin = .round
      return renderer
    }
  }
}

private final class FoldedMapView: MKMapView {
  var fold: MapFoldGeometry? {
    didSet { if fold != oldValue { updateFoldMask() } }
  }
  private let paperMask = CAShapeLayer()
  private var maskBounds = CGRect.null
  private var maskGeometry: MapFoldGeometry?

  override func layoutSubviews() {
    super.layoutSubviews()
    updateFoldMask()
  }

  private func updateFoldMask() {
    guard let fold, !bounds.isEmpty else {
      layer.mask = nil
      maskGeometry = nil
      return
    }
    guard bounds != maskBounds || fold != maskGeometry else { return }
    maskBounds = bounds
    maskGeometry = fold
    let path = CGMutablePath()
    path.addRect(bounds)
    path.addPath(
      fold.cutout.cgPath,
      transform: CGAffineTransform(
        translationX: bounds.maxX - MapFoldGeometry.canvasSize.width,
        y: bounds.maxY - MapFoldGeometry.canvasSize.height))
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    paperMask.frame = bounds
    paperMask.path = path
    paperMask.fillRule = .evenOdd
    paperMask.fillColor = UIColor.black.cgColor
    layer.mask = paperMask
    CATransaction.commit()
  }
}

final class PlaceAnnotation: NSObject, MKAnnotation {
  let place: MapPlace
  var coordinate: CLLocationCoordinate2D { place.coordinate }
  var title: String? { place.title() }
  init(_ place: MapPlace) { self.place = place }
}
