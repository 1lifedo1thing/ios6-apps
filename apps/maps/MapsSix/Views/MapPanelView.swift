import MapKit
import SwiftUI

struct MapPanelView: View {
  @Bindable var store: MapsStore
  let panel: MapsPanel
  let dismiss: () -> Void
  let directions: (MapPlace) -> Void
  let share: () -> Void
  @State private var bookmarkTab = 0
  @FocusState private var routeField: String?

  var body: some View {
    ZStack {
      if panel == .bookmarks {
        Color.white.ignoresSafeArea()
      } else {
        Pinstripe().ignoresSafeArea()
      }
      VStack(spacing: 0) {
        if panel == .bookmarks {
          ClassicHeader(
            title: ["Bookmarks", "Recents", "Landmarks"][bookmarkTab],
            prompt: ["Choose a bookmark", "Choose a recent search", "Choose a landmark"][
              bookmarkTab],
            onDone: dismiss,
            clear: bookmarkTab == 1 ? { store.clearRecents() } : nil,
            canClear: !store.recents.isEmpty)
        } else {
          ClassicHeader(
            title: title, back: "Back",
            onBack: {
              if panel == .directions { store.cancelOperation() }
              dismiss()
            })
        }
        switch panel {
        case .bookmarks: bookmarks
        case .directions: routeEditor
        case .detail: detail
        case .steps: steps
        case .preferences: preferences
        case .results: results
        }
      }
    }
    .accessibilityAddTraits(.isModal)
  }
  private var title: String {
    switch panel {
    case .bookmarks: "Bookmarks"
    case .directions: "Directions"
    case .detail: "Info"
    case .steps: "Route Steps"
    case .preferences: "Settings"
    case .results: "Search Results"
    }
  }
  private var bookmarks: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 0) {
          let items =
            bookmarkTab == 0
            ? store.bookmarks : bookmarkTab == 1 ? store.recents : MapPlace.landmarks
          if items.isEmpty {
            empty(
              bookmarkTab == 0 ? "No Bookmarks" : "No Recent Searches",
              subtitle: "Select a pin and choose Add Bookmark to save a place.")
          }
          ForEach(items) { place in
            PlaceRow(place: place) {
              store.select(place)
              dismiss()
            }
          }
        }
      }
      BookmarkSelector(selection: $bookmarkTab)
    }
  }
  private var routeEditor: some View {
    ScrollView {
      VStack(spacing: 18) {
        HStack(spacing: 0) {
          Button {
            store.walking = false
          } label: {
            Label(L10n.text("Driving"), systemImage: "car.fill")
          }.buttonStyle(MetalButton(blue: !store.walking)).accessibilityIdentifier(
            "transport-driving")
          Button {
            store.walking = true
          } label: {
            Label(L10n.text("Walking"), systemImage: "figure.walk")
          }.buttonStyle(MetalButton(blue: store.walking)).accessibilityIdentifier(
            "transport-walking")
          Button {
            routeField = nil
            store.openTransit()
          } label: {
            Image(systemName: "bus.fill")
          }.buttonStyle(MetalButton())
            .accessibilityLabel(L10n.text("Public Transport in Apple Maps"))
            .disabled(store.busy || store.destination.isEmpty)
        }.padding(.top, 10)
        VStack(spacing: 0) {
          routeInput(
            "Start", text: $store.origin, placeholder: "Current Location", id: "route-origin")
          Divider().padding(.leading, 65)
          routeInput(
            "End", text: $store.destination, placeholder: "Address or Place",
            id: "route-destination")
        }.background(.white, in: RoundedRectangle(cornerRadius: 9))
          .overlay(
            RoundedRectangle(cornerRadius: 9).stroke(.gray.opacity(0.5), lineWidth: 0.7)
              .allowsHitTesting(false))
        HStack {
          Button(L10n.text("Current Location")) {
            routeField = nil
            store.origin = ""
            store.locate()
          }.buttonStyle(MetalButton())
          Spacer()
          Button {
            let old = store.origin
            store.origin = store.destination
            store.destination = old
            store.routeDestination = nil
          } label: {
            Image(systemName: "arrow.up.arrow.down")
          }.buttonStyle(MetalButton())
            .accessibilityLabel(L10n.text("Swap Start and End"))
        }
        Button {
          routeField = nil
          store.calculateRoute()
        } label: {
          Text(L10n.text(store.busy ? "Calculating…" : "Route")).frame(maxWidth: .infinity)
        }
        .buttonStyle(MetalButton(blue: true)).disabled(
          store.busy || store.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .accessibilityIdentifier("calculate-route")
        if store.busy {
          ProgressView()
          Button(L10n.text("Cancel")) { store.cancelOperation() }.buttonStyle(MetalButton())
        }
        Text(L10n.text("Leave Start empty to use your location, or enter any starting address."))
          .font(MapTheme.font(13)).foregroundStyle(.secondary).frame(
            maxWidth: .infinity, alignment: .leading)
        Text(L10n.text("Landmarks")).font(MapTheme.font(14, bold: true)).frame(
          maxWidth: .infinity, alignment: .leading)
        VStack(spacing: 0) {
          ForEach(MapPlace.landmarks) { place in
            PlaceRow(place: place) {
              store.routeDestination = place
              store.destination = place.title()
              routeField = nil
            }
          }
        }.background(.white, in: RoundedRectangle(cornerRadius: 8)).clipShape(
          RoundedRectangle(cornerRadius: 8))
      }.padding(.horizontal, 14).padding(.bottom, 20)
    }.scrollDismissesKeyboard(.interactively)
  }
  private func routeInput(_ title: String, text: Binding<String>, placeholder: String, id: String)
    -> some View
  {
    HStack(spacing: 10) {
      Text(L10n.text(title) + ":").font(MapTheme.font(15, bold: true)).foregroundStyle(.gray).frame(
        width: 48, alignment: .trailing)
      TextField(L10n.text(placeholder), text: text).font(MapTheme.font(16))
        .focused($routeField, equals: id).autocorrectionDisabled()
        .accessibilityLabel(L10n.text(title)).accessibilityIdentifier(id)
        .submitLabel(id == "route-origin" ? .next : .route)
        .onSubmit {
          if id == "route-origin" {
            routeField = "route-destination"
          } else {
            routeField = nil
            store.calculateRoute()
          }
        }
    }.padding(12).frame(minHeight: 50)
  }
  private var detail: some View {
    ScrollView {
      if let place = store.selected {
        VStack(spacing: 16) {
          HStack(alignment: .top, spacing: 14) {
            Image("RedPin").resizable().scaledToFit().frame(width: 38, height: 55)
              .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
              Text(place.title()).font(MapTheme.font(24, bold: true)).accessibilityIdentifier(
                "place-title")
              Text(place.subtitle()).font(MapTheme.font(15)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
          }.padding(.vertical, 8)
          VStack(spacing: 0) {
            action("Directions to Here", symbol: "arrow.turn.up.right") { directions(place) }
            Divider()
            action("Directions from Here", symbol: "arrow.turn.up.left") {
              store.prepareDirections(to: nil)
              store.origin = place.title()
              store.destination = ""
              store.routeDestination = nil
              dismiss()
              directionsFrom(place)
            }
          }.classicGroup()
          VStack(spacing: 0) {
            action(
              store.bookmarks.contains(where: { $0.id == place.id })
                ? "Remove Bookmark" : "Add Bookmark", symbol: "book.closed"
            ) { store.toggleBookmark(place) }
            .accessibilityIdentifier("toggle-bookmark")
            Divider()
            action("Share Location", symbol: "square.and.arrow.up", perform: share)
            if let phone = place.phone,
              let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" })
            {
              Divider()
              action("Call", symbol: "phone.fill") { UIApplication.shared.open(url) }
            }
            if let website = place.website,
              ["http", "https"].contains(website.scheme?.lowercased() ?? "")
            {
              Divider()
              action("Website", symbol: "globe") { UIApplication.shared.open(website) }
            }
            Divider()
            action("Open in Apple Maps", symbol: "map") { place.mapItem.openInMaps() }
          }.classicGroup()
          Text(L10n.text("Coordinates")).font(MapTheme.font(13, bold: true)).foregroundStyle(
            .secondary)
          Text(
            String(
              format: "%.5f, %.5f", locale: Locale(identifier: "en_US_POSIX"), place.latitude,
              place.longitude)
          )
          .textSelection(.enabled).font(MapTheme.font(16))
          if place.isDroppedPin {
            Button(L10n.text("Remove Pin"), role: .destructive) {
              store.results.removeAll { $0.id == place.id }
              store.selected = nil
              dismiss()
            }.buttonStyle(MetalButton())
          }
        }.padding(18)
      }
    }
  }
  private func directionsFrom(_ place: MapPlace) {
    // The parent opens the editor; then restore the starting-place intent.
    directions(place)
    store.origin = place.title()
    store.destination = ""
    store.routeDestination = nil
  }
  private var steps: some View {
    ScrollView {
      VStack(spacing: 0) {
        if let route = store.route {
          VStack(spacing: 5) {
            Text("\(route.time) · \(store.units.distance(route.distance))").font(
              MapTheme.font(23, bold: true))
            Text(route.name).font(MapTheme.font(15))
            ForEach(route.advisory, id: \.self) {
              Text($0).font(MapTheme.font(13)).foregroundStyle(.secondary)
            }
          }.padding(20)
          ForEach(route.steps) { step in
            Button {
              store.previewStep(step.id)
              dismiss()
            } label: {
              HStack(alignment: .top, spacing: 14) {
                Text("\(step.id + 1)").font(MapTheme.font(19, bold: true)).foregroundStyle(
                  MapTheme.blue
                ).frame(width: 25)
                VStack(alignment: .leading, spacing: 5) {
                  Text(step.text).font(MapTheme.font(17, bold: true))
                  Text(store.units.distance(step.distance)).font(MapTheme.font(14)).foregroundStyle(
                    .gray)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").foregroundStyle(.gray)
              }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(.white)
            }.buttonStyle(.plain)
            Divider()
          }
          Button(L10n.text("Open in Apple Maps")) { store.externalDirections() }.buttonStyle(
            MetalButton()
          ).padding(20)
        } else {
          empty("No Route", subtitle: "Enter a start and destination to get directions.")
        }
      }
    }
  }
  private var preferences: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text(L10n.text("Distances")).font(MapTheme.font(17, bold: true)).padding(.top, 12)
        VStack(spacing: 0) {
          ForEach(MapUnits.allCases, id: \.rawValue) { unit in
            action(unit.rawValue, symbol: store.units == unit ? "checkmark" : "") {
              store.units = unit
            }
            .accessibilityIdentifier("units-\(unit.rawValue)")
            .accessibilityAddTraits(store.units == unit ? .isSelected : [])
            if unit != .miles { Divider() }
          }
        }.classicGroup()
        VStack(spacing: 0) {
          action(
            "Voice Navigation", symbol: store.voice ? "speaker.wave.2.fill" : "speaker.slash.fill"
          ) { store.voice.toggle() }
          .accessibilityValue(L10n.text(store.voice ? "On" : "Off")).accessibilityIdentifier(
            "voice-navigation")
          Divider()
          action("Flyover", symbol: "building.2") {
            store.style = .hybrid
            store.threeD = true
            store.flyover.toggle()
            dismiss()
          }.accessibilityIdentifier("flyover")
        }.classicGroup()
        Text(
          L10n.text(
            "Flyover and traffic coverage vary by region. Map labels and route instructions are supplied by Apple."
          )
        )
        .font(MapTheme.font(13)).foregroundStyle(.secondary)
        Text(
          L10n.text(
            "Navigation runs while Maps is open. Use Apple Maps for background and lock-screen guidance."
          )
        )
        .font(MapTheme.font(13)).foregroundStyle(.secondary)
        Text(L10n.text("MapsSix · Inspired by iOS 6")).font(MapTheme.font(14, bold: true)).frame(
          maxWidth: .infinity
        ).padding(.top, 15)
        Text(L10n.text("Map data © Apple and its providers")).font(MapTheme.font(12)).frame(
          maxWidth: .infinity)
      }.padding(18)
    }
  }
  private var results: some View {
    ScrollView {
      VStack(spacing: 0) {
        if store.results.isEmpty {
          empty("No Results", subtitle: "Search for a place or drop a pin on the map.")
        }
        ForEach(store.results) { place in
          PlaceRow(place: place) {
            store.select(place)
            dismiss()
          }
        }
      }
    }
  }
  private func action(_ key: String, symbol: String, perform: @escaping () -> Void) -> some View {
    Button(action: perform) {
      HStack(spacing: 12) {
        Image(systemName: symbol.isEmpty ? "circle" : symbol).foregroundStyle(
          symbol.isEmpty ? .clear : MapTheme.blue
        ).frame(width: 24)
        Text(L10n.text(key)).font(MapTheme.font(17, bold: true)).fixedSize(
          horizontal: false, vertical: true)
        Spacer(minLength: 0)
        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(
          .gray)
      }.padding(14).frame(minHeight: 51).contentShape(Rectangle())
    }.buttonStyle(.plain)
  }
  private func empty(_ title: String, subtitle: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "mappin.and.ellipse").font(.system(size: 38)).foregroundStyle(.gray)
      Text(L10n.text(title)).font(MapTheme.font(23, bold: true))
      Text(L10n.text(subtitle)).font(MapTheme.font(15)).multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
    }.frame(maxWidth: .infinity).padding(35)
  }
}

struct PlaceRow: View {
  let place: MapPlace
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image("RedPin").resizable().scaledToFit().frame(width: 20, height: 32).accessibilityHidden(
          true)
        VStack(alignment: .leading, spacing: 4) {
          Text(place.title()).font(MapTheme.font(17, bold: true))
          Text(place.subtitle()).font(MapTheme.font(13)).foregroundStyle(.gray).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(
          .gray)
      }.padding(14).frame(minHeight: 65).background(.white)
    }.buttonStyle(.plain).accessibilityIdentifier("place-\(place.id)")
    Divider()
  }
}

extension View {
  fileprivate func classicGroup() -> some View {
    background(.white, in: RoundedRectangle(cornerRadius: 9))
      .overlay(
        RoundedRectangle(cornerRadius: 9).stroke(.gray.opacity(0.45), lineWidth: 0.7)
          .allowsHitTesting(false))
  }
}

struct MapShareView: UIViewControllerRepresentable {
  let place: MapPlace
  func makeUIViewController(context: Context) -> UIActivityViewController {
    var components = URLComponents(string: "https://maps.apple.com/")!
    components.queryItems = [
      URLQueryItem(name: "ll", value: "\(place.latitude),\(place.longitude)"),
      URLQueryItem(name: "q", value: place.title()),
    ]
    return UIActivityViewController(
      activityItems: [place.title(), place.subtitle(), components.url!], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
