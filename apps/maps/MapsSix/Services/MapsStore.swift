import AVFoundation
import MapKit
import Observation
import UIKit

@MainActor @Observable
final class MapsStore {
  var query = ""
  var results: [MapPlace] = []
  var selected: MapPlace?
  var bookmarks: [MapPlace] = []
  var recents: [MapPlace] = []
  var style: MapStyle { didSet { defaults.set(style.rawValue, forKey: "style") } }
  var traffic: Bool { didSet { defaults.set(traffic, forKey: "traffic") } }
  var threeD = false
  var units: MapUnits { didSet { defaults.set(units.rawValue, forKey: "units") } }
  var voice: Bool {
    didSet {
      defaults.set(voice, forKey: "voice")
      if !voice { speech.stopSpeaking(at: .immediate) }
    }
  }
  var busy = false
  var error: String?
  var routes: [MapRoute] = []
  var routeIndex = 0
  var stepIndex = 0
  var navigating = false
  var arrived = false
  var offRoute = false
  var remainingDistance: Double?
  var walking = false
  var origin = ""
  var destination = ""
  var routeDestination: MapPlace?
  var region = MKCoordinateRegion(
    center: .init(latitude: 37.7935, longitude: -122.407),
    span: .init(latitudeDelta: 0.028, longitudeDelta: 0.028))
  var cameraRevision = 0
  var cameraTarget: CLLocationCoordinate2D?
  var routeRevision = 0
  var follow = false
  var flyover = false
  let location: LocationService
  let testing: Bool
  private let automaticallyLocate: Bool
  private var started = false
  private let defaults: UserDefaults
  private var search: MKLocalSearch?
  private var directions: MKDirections?
  private var operation: Task<Void, Never>?
  private var generation = UUID()
  private let speech = AVSpeechSynthesizer()
  private var previousIdleTimerDisabled = false
  private var lastReroute: Date = .distantPast
  private var snapshotter: MKMapSnapshotter?
  var route: MapRoute? { routes.indices.contains(routeIndex) ? routes[routeIndex] : nil }
  var instruction: RouteInstruction? {
    guard let route, route.steps.indices.contains(stepIndex) else { return nil }
    return route.steps[stepIndex]
  }
  var maneuverSymbol: String {
    let text = instruction?.text.lowercased() ?? ""
    if text.contains("arriv") || text.contains("到达") { return "flag.checkered" }
    if text.contains("u-turn") || text.contains("掉头") { return "arrow.uturn.down" }
    if text.contains("left") || text.contains("左") { return "arrow.turn.up.left" }
    if text.contains("right") || text.contains("右") { return "arrow.turn.up.right" }
    return "arrow.up"
  }
  var navigationDistance: Double { remainingDistance ?? route?.distance ?? 0 }
  var navigationTime: String {
    guard let route else { return "" }
    let fraction = route.distance > 0 ? navigationDistance / route.distance : 1
    return L10n.format("%d min", max(1, Int((route.duration * fraction / 60).rounded(.up))))
  }

  init(
    defaults: UserDefaults = .standard, testing: Bool = false,
    automaticallyLocate: Bool = true, locationService: LocationService? = nil
  ) {
    self.defaults = defaults
    self.testing = testing
    self.automaticallyLocate = automaticallyLocate && !testing
    self.location = locationService ?? LocationService()
    style = MapStyle(rawValue: defaults.string(forKey: "style") ?? "") ?? .standard
    traffic = defaults.bool(forKey: "traffic")
    units = MapUnits(rawValue: defaults.string(forKey: "units") ?? "") ?? .automatic
    voice = defaults.object(forKey: "voice") as? Bool ?? true
    bookmarks = Self.restore("bookmarks", defaults: defaults)
    recents = Self.restore("recents", defaults: defaults)
    if self.automaticallyLocate {
      region = MKCoordinateRegion(
        center: .init(latitude: 0, longitude: 0),
        span: .init(latitudeDelta: 100, longitudeDelta: 200))
    }
    location.onUpdate = { [weak self] sample in self?.updateNavigation(sample) }
  }
  func start() {
    guard !started else { return }
    started = true
    if automaticallyLocate { locate() }
  }
  static func restore(_ key: String, defaults: UserDefaults) -> [MapPlace] {
    guard let data = defaults.data(forKey: key),
      let places = try? JSONDecoder().decode([MapPlace].self, from: data)
    else { return [] }
    var ids = Set<String>()
    return places.filter { $0.isValid && ids.insert($0.id).inserted }.prefix(50).map { $0 }
  }
  private func persist() {
    defaults.set(try? JSONEncoder().encode(bookmarks), forKey: "bookmarks")
    defaults.set(try? JSONEncoder().encode(recents), forKey: "recents")
  }
  func remember(_ place: MapPlace) {
    recents.removeAll { $0.id == place.id }
    recents.insert(place, at: 0)
    recents = Array(recents.prefix(30))
    persist()
  }
  func toggleBookmark(_ place: MapPlace) {
    if bookmarks.contains(where: { $0.id == place.id }) {
      bookmarks.removeAll { $0.id == place.id }
    } else {
      bookmarks.insert(place, at: 0)
    }
    persist()
  }
  func clearRecents() {
    recents.removeAll()
    persist()
  }
  func select(_ place: MapPlace) {
    guard place.isValid else { return }
    if routeDestination?.id != place.id { endNavigation(clearRoute: true) }
    selected = place
    if !results.contains(where: { $0.id == place.id }) { results = [place] }
    remember(place)
    focus(place.coordinate)
  }
  func focus(_ point: CLLocationCoordinate2D) {
    cameraTarget = point
    follow = false
    cameraRevision += 1
  }
  func locate() {
    if testing {
      location.location = CLLocation(latitude: 37.7955, longitude: -122.3937)
    } else {
      location.request()
    }
    follow = true
    if let point = location.location?.coordinate {
      focus(point)
      follow = true
    }
  }
  func dropPin(_ point: CLLocationCoordinate2D? = nil) { select(.pin(point ?? region.center)) }
  func cancelOperation() {
    generation = UUID()
    operation?.cancel()
    search?.cancel()
    directions?.cancel()
    busy = false
  }
  func submitSearch() {
    let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    endNavigation(clearRoute: true)
    cancelOperation()
    let token = generation
    busy = true
    error = nil
    operation = Task {
      defer { if token == generation { busy = false } }
      do {
        let places: [MapPlace]
        if testing {
          places = MapPlace.landmarks.filter {
            $0.name.localizedCaseInsensitiveContains(value)
              || ($0.chineseName?.contains(value) ?? false)
          }
        } else {
          places = try await find(value)
        }
        guard !Task.isCancelled, token == generation else { return }
        results = places
        selected = places.first
        if let place = places.first {
          remember(place)
          focus(place.coordinate)
        } else {
          error = L10n.text("No Results Found. Try a place name or a full address.")
        }
      } catch {
        guard !Task.isCancelled, token == generation else { return }
        self.error = L10n.text("Search is unavailable. Check your connection and try again.")
      }
    }
  }
  private func find(_ query: String) async throws -> [MapPlace] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.region = region
    let service = MKLocalSearch(request: request)
    search = service
    return try await service.start().mapItems.map(MapPlace.from).filter(\.isValid)
  }
  func prepareDirections(to place: MapPlace? = nil) {
    routeDestination = place ?? selected
    destination = routeDestination?.title() ?? ""
    origin = ""
  }
  func calculateRoute() {
    cancelOperation()
    let token = generation
    let startText = origin.trimmingCharacters(in: .whitespacesAndNewlines)
    let endText = destination.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !endText.isEmpty else {
      error = L10n.text("Enter a destination.")
      return
    }
    if startText.isEmpty && !testing {
      location.request()
      guard let sample = location.location, LocationService.valid(sample),
        sample.horizontalAccuracy <= 150
      else {
        error = L10n.text(
          "Waiting for your location. Try again when located, or enter a starting address.")
        return
      }
    }
    busy = true
    error = nil
    operation = Task {
      defer { if token == generation { busy = false } }
      do {
        let end: MapPlace
        let start: MKMapItem
        if testing {
          end = routeDestination ?? MapPlace.landmarks[1]
          start = MapPlace.landmarks[0].mapItem
        } else {
          if let cached = routeDestination, endText == cached.title() {
            end = cached
          } else if let found = try await find(endText).first {
            end = found
          } else {
            throw MKError(.placemarkNotFound)
          }
          guard !Task.isCancelled, token == generation else { return }
          if startText.isEmpty, let current = location.location {
            start = MKMapItem(placemark: MKPlacemark(coordinate: current.coordinate))
          } else if let first = try await find(startText).first {
            start = first.mapItem
          } else {
            throw MKError(.placemarkNotFound)
          }
        }
        guard !Task.isCancelled, token == generation else { return }
        let calculated: [MapRoute]
        if testing {
          calculated = [Self.fixtureRoute()]
        } else {
          let request = MKDirections.Request()
          request.source = start
          request.destination = end.mapItem
          request.transportType = walking ? .walking : .automobile
          request.requestsAlternateRoutes = true
          let service = MKDirections(request: request)
          directions = service
          let response = try await service.calculate()
          calculated = response.routes.enumerated().map { index, route in
            let steps = route.steps.filter { !$0.instructions.isEmpty }.enumerated().map {
              RouteInstruction(
                id: $0.offset, text: AppLanguage.current.placeName($0.element.instructions),
                distance: $0.element.distance,
                coordinate: $0.element.polyline.pointCount > 0
                  ? $0.element.polyline.points()[0].coordinate : end.coordinate)
            }
            return MapRoute(
              id: "\(index)", name: route.name, distance: route.distance,
              duration: route.expectedTravelTime, polyline: route.polyline,
              steps: steps, advisory: route.advisoryNotices)
          }
        }
        guard !Task.isCancelled, token == generation else { return }
        guard !calculated.isEmpty else { throw MKError(.directionsNotFound) }
        routes = calculated
        routeIndex = 0
        stepIndex = 0
        remainingDistance = nil
        routeDestination = end
        results = [end]
        selected = nil
        remember(end)
        routeRevision += 1
        offRoute = false
        if navigating { speak() }
      } catch {
        guard !Task.isCancelled, token == generation else { return }
        self.error = L10n.text(
          "Directions are unavailable. Check both addresses and your connection, then try again.")
      }
    }
  }
  func chooseRoute(_ index: Int) {
    guard routes.indices.contains(index) else { return }
    routeIndex = index
    stepIndex = 0
    remainingDistance = nil
    routeRevision += 1
  }
  func startNavigation() {
    guard !navigating, route != nil else { return }
    navigating = true
    arrived = false
    offRoute = false
    previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    UIApplication.shared.isIdleTimerDisabled = true
    threeD = !walking
    follow = true
    if !testing { location.request() }
    if let point = instruction?.coordinate {
      cameraTarget = point
      cameraRevision += 1
    }
    speak()
  }
  func endNavigation(clearRoute: Bool = false) {
    if navigating { UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled }
    navigating = false
    speech.stopSpeaking(at: .immediate)
    follow = false
    offRoute = false
    remainingDistance = nil
    if clearRoute {
      routes = []
      routeDestination = nil
      routeRevision += 1
    }
  }
  func previewStep(_ index: Int) {
    guard let route, route.steps.indices.contains(index) else { return }
    stepIndex = index
    focus(route.steps[index].coordinate)
    if navigating { speak() }
  }
  private func speak() {
    guard voice, let instruction else { return }
    speech.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: instruction.text)
    utterance.voice = AVSpeechSynthesisVoice(
      language: AppLanguage.current == .chinese ? "zh-CN" : "en-GB")
    speech.speak(utterance)
  }
  private func updateNavigation(_ sample: CLLocation) {
    if follow {
      cameraTarget = sample.coordinate
      cameraRevision += 1
    }
    guard navigating, let route, sample.horizontalAccuracy <= 150 else { return }
    if let end = routeDestination,
      sample.distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude)) < 30
    {
      arrived = true
      endNavigation(clearRoute: true)
      return
    }
    let next = RouteProgress.nextIndex(current: stepIndex, steps: route.steps, location: sample)
    if next != stepIndex {
      stepIndex = next
      speak()
    }
    let point = MKMapPoint(sample.coordinate)
    var nearest = Double.greatestFiniteMagnitude
    var remaining = 0.0
    var bestRemaining = route.distance
    let points = route.polyline.points()
    if route.polyline.pointCount > 1 {
      for index in (1..<route.polyline.pointCount).reversed() {
        let a = points[index - 1]
        let b = points[index]
        let dx = b.x - a.x
        let dy = b.y - a.y
        let divisor = dx * dx + dy * dy
        let t =
          divisor > 0 ? max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / divisor)) : 0
        let deviation = point.distance(to: MKMapPoint(x: a.x + t * dx, y: a.y + t * dy))
        let segmentLength = a.distance(to: b)
        if deviation < nearest {
          nearest = deviation
          bestRemaining = remaining + segmentLength * (1 - t)
        }
        remaining += segmentLength
      }
    }
    remainingDistance = bestRemaining
    offRoute = nearest > max(80, sample.horizontalAccuracy * 2)
    if offRoute && !busy && Date().timeIntervalSince(lastReroute) > 30 {
      lastReroute = Date()
      origin = ""
      calculateRoute()
    }
  }
  func externalDirections(transit: Bool = false) {
    guard let place = routeDestination ?? selected else { return }
    place.mapItem.openInMaps(launchOptions: [
      MKLaunchOptionsDirectionsModeKey:
        transit
        ? MKLaunchOptionsDirectionsModeTransit
        : walking ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
    ])
  }
  func openTransit() {
    let text = destination.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    cancelOperation()
    let token = generation
    busy = true
    operation = Task {
      defer { if token == generation { busy = false } }
      do {
        let place: MapPlace?
        if let cached = routeDestination, text == cached.title() {
          place = cached
        } else {
          place = try await find(text).first
        }
        guard token == generation, !Task.isCancelled else { return }
        guard let place else { throw MKError(.placemarkNotFound) }
        routeDestination = place
        externalDirections(transit: true)
      } catch {
        guard token == generation, !Task.isCancelled else { return }
        self.error = L10n.text("Search is unavailable. Check your connection and try again.")
      }
    }
  }
  func printMap() {
    let options = MKMapSnapshotter.Options()
    options.region = region
    options.size = CGSize(width: 700, height: 900)
    options.mapType = style.type(threeD: false)
    let service = MKMapSnapshotter(options: options)
    snapshotter = service
    Task {
      do {
        let snapshot = try await service.start()
        let image = UIGraphicsImageRenderer(size: options.size).image { context in
          snapshot.image.draw(at: .zero)
          if let route {
            let points = route.polyline.points()
            let path = UIBezierPath()
            for index in 0..<route.polyline.pointCount {
              let point = snapshot.point(for: points[index].coordinate)
              if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            UIColor.systemBlue.setStroke()
            path.lineWidth = 5
            path.stroke()
          }
          for place in results {
            let point = snapshot.point(for: place.coordinate)
            UIImage(named: "RedPin")?.draw(
              in: CGRect(x: point.x - 16, y: point.y - 42, width: 32, height: 42))
          }
        }
        let printer = UIPrintInteractionController.shared
        printer.printingItem = image
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = L10n.text("Maps")
        info.outputType = .general
        printer.printInfo = info
        printer.present(animated: true) { _, _, error in
          if error != nil { self.error = L10n.text("Printing is unavailable. Please try again.") }
        }
      } catch {
        self.error = L10n.text(
          "The map could not be prepared for printing. Check your connection and try again.")
      }
      snapshotter = nil
    }
  }
  static func fixtureRoute() -> MapRoute {
    let coordinates = [
      MapPlace.landmarks[0].coordinate,
      CLLocationCoordinate2D(latitude: 37.799, longitude: -122.3988),
      CLLocationCoordinate2D(latitude: 37.802, longitude: -122.402),
      MapPlace.landmarks[1].coordinate,
    ]
    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
    let texts = [
      L10n.text("Head northwest on The Embarcadero"), L10n.text("Turn left onto Broadway"),
      L10n.text("Turn right onto Montgomery Street"), L10n.text("Arrive at Coit Tower"),
    ]
    return MapRoute(
      id: "fixture", name: "The Embarcadero", distance: 1800, duration: 420,
      polyline: polyline,
      steps: coordinates.enumerated().map {
        RouteInstruction(
          id: $0.offset, text: texts[$0.offset], distance: $0.offset == 3 ? 0 : 600,
          coordinate: $0.element)
      }, advisory: [])
  }
}
