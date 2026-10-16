import SwiftUI

enum MapsPanel { case bookmarks, directions, detail, steps, preferences, results }

struct MapsRootView: View {
  @Bindable var store: MapsStore
  @State private var panel: MapsPanel?
  @State private var pageOpen = false
  @State private var pageImage: UIImage?
  @State private var pageCloseAction: (() -> Void)?
  @State private var pageSnapshot = MapPageSnapshot()
  @State private var searching = false
  @State private var share = false
  @FocusState private var searchFocused: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { screen in
      let cornerScale = min(1.25, max(1, min(screen.size.width, screen.size.height) / 320))
      let fold = MapFoldGeometry(
        scale: cornerScale,
        roundedDisplay: screen.safeAreaInsets.bottom > 0 || screen.safeAreaInsets.leading > 0
          || screen.safeAreaInsets.trailing > 0)
      ZStack {
        MapLinen().ignoresSafeArea().accessibilityHidden(true)
        ClassicMapView(
          store: store, pageSnapshot: pageSnapshot,
          contentInsets: UIEdgeInsets(
            top: screen.safeAreaInsets.top + 50, left: screen.safeAreaInsets.leading,
            bottom: screen.safeAreaInsets.bottom, right: screen.safeAreaInsets.trailing),
          interactive: panel == nil && !pageOpen && !searching,
          fold: mapControlsVisible ? fold : nil
        )
        .ignoresSafeArea()
        .allowsHitTesting(panel == nil && !pageOpen && !searching)
        .accessibilityHidden(panel != nil || searching || pageOpen)
        VStack(spacing: 0) {
          Group {
            if store.navigating { navigationHeader } else { searchHeader }
          }
          .brightness(pageOpen ? -0.16 : 0).allowsHitTesting(!pageOpen)
          .accessibilityHidden(pageOpen)
          ZStack(alignment: .bottom) {
            MapLinen().opacity(pageImage != nil || pageOpen ? 1 : 0)
              .accessibilityHidden(true)
            if pageOpen || pageImage != nil {
              mapOptions.opacity(pageOpen ? 1 : 0)
                .allowsHitTesting(pageOpen).accessibilityHidden(!pageOpen)
                .transition(.identity)
            }
            if let pageImage {
              MapPaperView(image: pageImage, progress: pageOpen ? 1 : 0, reduceMotion: reduceMotion)
              {
                if !pageOpen {
                  self.pageImage = nil
                  let action = pageCloseAction
                  pageCloseAction = nil
                  action?()
                }
              }
              .allowsHitTesting(false).accessibilityHidden(true)
            }
            if !pageOpen && !searching {
              VStack(spacing: 8) {
                if store.location.locating && store.follow { notice("Locating…") }
                if store.location.approximate { notice("Approximate Location") }
                if store.location.authorization == .denied
                  || store.location.authorization == .restricted
                {
                  notice(
                    "Location access is off. Enable it in Settings, or enter a starting address.")
                }
                if store.navigating {
                  turnSign
                } else if let place = store.selected {
                  placeBubble(place)
                }
                if let route = store.route, !store.navigating { routeSummary(route) }
                if store.arrived { notice("You have arrived.") }
                if store.offRoute { notice("Recalculating route…") }
                Spacer(minLength: 0)
              }.padding(12)
            }
            if searching { searchResults }
            if store.busy {
              HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text(L10n.text("Loading…"))
                Button(L10n.text("Cancel")) { store.cancelOperation() }.foregroundStyle(.white)
              }.font(MapTheme.font(14, bold: true)).padding(13)
                .background(MapTheme.graphite, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white).padding(.bottom, 20)
            }
            if pageOpen && screen.size.height >= 450 {
              VStack(spacing: 0) {
                Button {
                  turnPage(open: false)
                } label: {
                  Color.clear.frame(height: max(60, screen.size.height * 0.24)).contentShape(
                    Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(L10n.text("Close Map Options"))
                .accessibilityIdentifier("map-options")
                Spacer(minLength: 0).allowsHitTesting(false)
              }
            }
          }.clipped()
        }.ignoresSafeArea(.container, edges: .bottom)
          .accessibilityHidden(panel != nil).allowsHitTesting(panel == nil)
        if mapControlsVisible {
          HStack(alignment: .bottom, spacing: 0) {
            mapButtons
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 8).padding(.bottom, 8)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .ignoresSafeArea(.keyboard, edges: .bottom)
          .transition(.identity).zIndex(1)
          pageCorner(geometry: fold)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .ignoresSafeArea()
            .transition(.identity).zIndex(1)
        }
        if let panel {
          MapPanelView(
            store: store, panel: panel, dismiss: { self.panel = nil },
            directions: {
              store.prepareDirections(to: $0)
              self.panel = .directions
            },
            share: { share = true }
          )
          .transition(.move(edge: .trailing))
          .zIndex(2)
        }
      }
      .font(MapTheme.font(16)).foregroundStyle(MapTheme.ink)
      .environment(\.colorScheme, .light)
      .preferredColorScheme(panel == nil && store.style != .standard ? .dark : .light)
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: panel)
      .task { store.start() }
      .onChange(of: store.routeRevision) {
        if store.route != nil {
          panel = nil
          searching = false
          searchFocused = false
        }
      }
      .onChange(of: store.busy) {
        if !store.busy && !store.results.isEmpty && store.error == nil {
          searching = false
          searchFocused = false
        }
      }
      .onChange(of: searchFocused) {
        if searchFocused {
          searching = true
          turnPage(open: false)
        }
      }
      .onChange(of: screen.size) {
        if pageOpen {
          Task { @MainActor in
            await Task.yield()
            pageImage = pageSnapshot.capture?()
          }
        }
      }
      .onChange(of: scenePhase) {
        if scenePhase == .active {
          store.location.resume()
        } else if scenePhase == .background {
          store.location.suspend()
        }
      }
      .alert(
        L10n.text("Maps"),
        isPresented: Binding(
          get: { store.error != nil || store.location.error != nil },
          set: {
            if !$0 {
              store.error = nil
              store.location.error = nil
            }
          })
      ) {
        Button(L10n.text("OK"), role: .cancel) {
          store.error = nil
          store.location.error = nil
        }
        if store.location.authorization == .denied {
          Button(L10n.text("Settings")) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }
        }
      } message: {
        Text(store.error ?? store.location.error ?? "")
      }
      .sheet(isPresented: $share) {
        if let place = store.selected ?? store.routeDestination { MapShareView(place: place) }
      }
      .accessibilityAction(.escape) {
        if panel != nil {
          panel = nil
        } else {
          turnPage(open: false)
          searching = false
          searchFocused = false
        }
      }
    }
  }

  private var searchHeader: some View {
    ChromePanel {
      HStack(spacing: 7) {
        Button {
          store.prepareDirections()
          panel = .directions
          searchFocused = false
          searching = false
        } label: {
          Image(systemName: "arrow.turn.up.right").font(.system(size: 21, weight: .bold))
        }.buttonStyle(MetalButton()).accessibilityLabel(L10n.text("Directions"))
          .accessibilityIdentifier("directions")
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass").foregroundStyle(.gray).font(
            .system(size: 15, weight: .bold))
          TextField(L10n.text("Search or Address"), text: $store.query)
            .font(MapTheme.font(16)).focused($searchFocused).submitLabel(.search)
            .autocorrectionDisabled().textInputAutocapitalization(.words)
            .accessibilityIdentifier("map-search").onSubmit { store.submitSearch() }
          if !store.query.isEmpty {
            Button {
              store.query = ""
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
            }
            .accessibilityLabel(L10n.text("Clear Search")).frame(width: 28, height: 36)
          }
        }.padding(.leading, 8).frame(height: 32)
          .background(.white, in: RoundedRectangle(cornerRadius: 6))
          .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.35), lineWidth: 0.8)
              .allowsHitTesting(false)
          )
          .shadow(color: .white.opacity(0.9), radius: 0, y: 1)
        if searching {
          Button(L10n.text("Cancel")) {
            store.cancelOperation()
            searching = false
            searchFocused = false
          }
          .buttonStyle(MetalButton()).accessibilityIdentifier("cancel-search")
        } else {
          Button {
            panel = .bookmarks
          } label: {
            Image(systemName: "book.closed.fill").font(.system(size: 19))
          }
          .buttonStyle(MetalButton()).accessibilityLabel(L10n.text("Bookmarks"))
          .accessibilityIdentifier("bookmarks")
        }
      }.padding(.horizontal, 7).frame(height: 50)
    }
  }
  private var navigationHeader: some View {
    ChromePanel {
      HStack {
        Button(L10n.text("End Navigation")) { store.endNavigation() }.buttonStyle(MetalButton())
          .accessibilityIdentifier("end-navigation")
        Spacer()
        VStack(spacing: 0) {
          Text(store.navigationTime).font(MapTheme.font(20, bold: true))
          Text(store.units.distance(store.navigationDistance)).font(MapTheme.font(12))
        }
        Spacer()
        Button(L10n.text("Overview")) { store.routeRevision += 1 }.buttonStyle(MetalButton())
      }.padding(.horizontal, 8).frame(height: 50)
    }
  }
  private var mapControlsVisible: Bool {
    panel == nil && !pageOpen && pageImage == nil && !searching && !searchFocused
  }

  private var mapButtons: some View {
    HStack(spacing: 0) {
      Button {
        store.locate()
      } label: {
        Image(systemName: store.follow ? "location.fill" : "location").font(
          .system(size: 22, weight: .semibold)
        ).foregroundStyle(MapTheme.blue)
      }.buttonStyle(MapFloatingButton()).accessibilityLabel(L10n.text("Current Location"))
        .accessibilityIdentifier("locate")
      Button {
        store.threeD.toggle()
      } label: {
        Text("3D").font(MapTheme.font(17, bold: true)).foregroundStyle(
          store.threeD ? MapTheme.blue : MapTheme.ink)
      }
      .buttonStyle(MapFloatingButton()).accessibilityLabel(L10n.text("3D Map"))
      .accessibilityValue(
        L10n.text(store.threeD ? "On" : "Off")
      ).accessibilityIdentifier("three-d")
      if store.navigating {
        Button {
          panel = .steps
        } label: {
          Image(systemName: "list.bullet").font(.system(size: 21))
        }
        .buttonStyle(MapFloatingButton()).accessibilityLabel(L10n.text("Route Steps"))
      } else if store.selected != nil {
        Button {
          share = true
        } label: {
          Image(systemName: "square.and.arrow.up").font(.system(size: 21))
        }
        .buttonStyle(MapFloatingButton()).accessibilityLabel(L10n.text("Share Location"))
        .accessibilityIdentifier("share-location")
      }
    }
    .background(MapTheme.silver, in: RoundedRectangle(cornerRadius: 5))
    .overlay(
      RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.45), lineWidth: 0.7)
        .allowsHitTesting(false)
    )
    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    .transaction { $0.animation = nil }
  }

  private func pageCorner(geometry: MapFoldGeometry) -> some View {
    Button {
      searchFocused = false
      searching = false
      turnPage(open: true)
    } label: {
      CurlCorner(geometry: geometry)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.text("Map Options"))
    .accessibilityIdentifier("map-options")
  }

  private func placeBubble(_ place: MapPlace) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Button {
          store.prepareDirections(to: place)
          panel = .directions
        } label: {
          Image(systemName: "car.fill").font(.system(size: 21)).frame(width: 40, height: 44)
        }
        .accessibilityLabel(L10n.text("Directions to Here")).accessibilityIdentifier(
          "bubble-directions")
        VStack(alignment: .leading, spacing: 3) {
          Text(place.title()).font(MapTheme.font(17, bold: true)).lineLimit(2)
          Text(place.subtitle()).font(MapTheme.font(12)).lineLimit(2).opacity(0.85)
        }.frame(maxWidth: .infinity, alignment: .leading)
        Button {
          panel = .detail
        } label: {
          Image(systemName: "chevron.right.circle.fill").font(.system(size: 27)).foregroundStyle(
            Color(red: 0.45, green: 0.68, blue: 0.96))
        }.frame(width: 44, height: 44).accessibilityLabel(L10n.text("Place Information"))
          .accessibilityIdentifier("place-info")
        Button {
          store.selected = nil
        } label: {
          Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
        }
        .frame(width: 28, height: 44).accessibilityLabel(L10n.text("Close"))
      }.padding(5).foregroundStyle(.white)
        .background(MapTheme.graphite, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
          RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.7), lineWidth: 1)
            .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
      Triangle().fill(Color(white: 0.18)).frame(width: 18, height: 10)
    }
  }
  private func routeSummary(_ route: MapRoute) -> some View {
    VStack(spacing: 5) {
      HStack {
        Text("\(route.time) · \(store.units.distance(route.distance))").font(
          MapTheme.font(18, bold: true))
        Spacer()
        Button(L10n.text("Start Navigation")) { store.startNavigation() }.buttonStyle(
          MetalButton(blue: true)
        ).accessibilityIdentifier("start-navigation")
      }
      HStack {
        Text(route.name).font(MapTheme.font(13)).lineLimit(1)
        Spacer()
        Button(L10n.text("List")) { panel = .steps }.accessibilityIdentifier("route-list")
        Button(L10n.text("Clear")) { store.endNavigation(clearRoute: true) }.padding(.leading, 14)
      }.font(MapTheme.font(14, bold: true))
      if store.routes.count > 1 {
        HStack {
          ForEach(Array(store.routes.enumerated()), id: \.element.id) { index, route in
            Button(route.time) { store.chooseRoute(index) }.buttonStyle(
              MetalButton(blue: store.routeIndex == index))
          }
        }
      }
    }.padding(10).background(
      Color(white: 0.96).opacity(0.96), in: RoundedRectangle(cornerRadius: 6)
    )
    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
  }
  private var turnSign: some View {
    VStack(spacing: 5) {
      HStack(alignment: .center, spacing: 14) {
        Image(systemName: store.maneuverSymbol).font(.system(size: 41, weight: .bold))
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(store.instruction.map { store.units.distance($0.distance) } ?? "").font(
            MapTheme.font(24, bold: true))
          Text(store.instruction?.text ?? "").font(MapTheme.font(21, bold: true)).fixedSize(
            horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack {
        Button {
          store.previewStep(store.stepIndex - 1)
        } label: {
          Image(systemName: "chevron.left")
        }.disabled(store.stepIndex == 0)
          .accessibilityLabel(L10n.text("Previous Step")).frame(width: 44, height: 36)
        Spacer()
        Text(L10n.format("Step %d of %d", store.stepIndex + 1, store.route?.steps.count ?? 0)).font(
          MapTheme.font(12))
        Spacer()
        Button {
          store.previewStep(store.stepIndex + 1)
        } label: {
          Image(systemName: "chevron.right")
        }
        .disabled(store.stepIndex + 1 >= (store.route?.steps.count ?? 0))
        .accessibilityLabel(L10n.text("Next Step")).accessibilityIdentifier("next-step").frame(
          width: 44, height: 36)
      }
    }.padding(.horizontal, 14).padding(.top, 14).foregroundStyle(.white)
      .background(
        LinearGradient(
          colors: [
            Color(red: 0.23, green: 0.47, blue: 0.25), Color(red: 0.06, green: 0.29, blue: 0.15),
          ], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 8)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.85), lineWidth: 2).padding(4)
          .allowsHitTesting(false)
      )
      .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
  }
  private func notice(_ key: String) -> some View {
    Text(L10n.text(key)).padding(10).frame(maxWidth: .infinity).background(
      .white, in: RoundedRectangle(cornerRadius: 5))
  }
  private func turnPage(open: Bool, completion: (() -> Void)? = nil) {
    pageCloseAction = open ? nil : completion
    if open && pageImage == nil { pageImage = pageSnapshot.capture?() }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) {
      pageOpen = open
    }
    if !open && pageImage == nil {
      pageCloseAction = nil
      completion?()
    }
  }

  private func closePage(then action: @escaping () -> Void) {
    turnPage(open: false, completion: action)
  }

  private var mapOptions: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 450
      ZStack(alignment: .bottom) {
        MapLinen().ignoresSafeArea()
        ScrollView {
          VStack(spacing: 12) {
            HStack(spacing: 8) {
              Text(L10n.text("Map data © Apple and its providers"))
                .font(MapTheme.font(10)).lineLimit(2)
              Spacer(minLength: 0)
              Button(L10n.text("Report a Problem")) {
                closePage {
                  (store.selected ?? MapPlace.pin(store.region.center)).mapItem.openInMaps()
                }
              }.font(MapTheme.font(10, bold: true))
              Button {
                closePage { panel = .preferences }
              } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 18))
                  .frame(width: 36, height: 36).contentShape(Rectangle())
              }.accessibilityLabel(L10n.text("Settings")).accessibilityIdentifier("map-settings")
            }.foregroundStyle(Color(white: 0.88)).buttonStyle(.plain)
            HStack(spacing: 10) {
              Button(L10n.text("Drop Pin")) { closePage { store.dropPin() } }
                .accessibilityIdentifier("drop-pin")
              Button(L10n.text("Print Map")) { closePage { store.printMap() } }
                .accessibilityIdentifier("print-map")
            }
            HStack(spacing: 10) {
              Button(L10n.text(store.traffic ? "Hide Traffic" : "Show Traffic")) {
                store.traffic.toggle()
              }.accessibilityIdentifier("traffic")
              Button(L10n.text("List Results")) { closePage { panel = .results } }
            }
            HStack(spacing: 0) {
              ForEach(MapStyle.allCases) { style in
                Button(L10n.text(style.rawValue)) { store.style = style }
                  .buttonStyle(
                    MapOptionSegment(
                      selected: store.style == style,
                      first: style == .standard, last: style == .hybrid)
                  )
                  .accessibilityIdentifier("style-\(style.rawValue)")
                  .accessibilityAddTraits(store.style == style ? .isSelected : [])
              }
            }
          }
          .buttonStyle(MapOptionButton())
          .padding(.horizontal, 16).padding(.bottom, compact ? 16 : 48)
        }
        .padding(.top, compact ? 48 : 0)
        .frame(maxHeight: compact ? geometry.size.height : 270)
      }
      .overlay(alignment: .topTrailing) {
        if compact {
          Button(L10n.text("Done")) { turnPage(open: false) }
            .buttonStyle(MetalButton()).padding(.trailing, 10)
            .accessibilityLabel(L10n.text("Close Map Options"))
            .accessibilityIdentifier("map-options")
        }
      }
    }
    .font(MapTheme.font(16)).foregroundStyle(MapTheme.ink)
    .preferredColorScheme(.light)
    .accessibilityAction(.escape) { turnPage(open: false) }
  }
  private var searchResults: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        if !store.query.isEmpty {
          Button {
            searchFocused = false
            store.submitSearch()
          } label: {
            HStack {
              Image(systemName: "magnifyingglass")
              Text(L10n.format("Search for “%@”", store.query))
              Spacer()
              Image(systemName: "chevron.right")
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
          }.accessibilityIdentifier("submit-search")
          Divider()
        }
        Text(L10n.text(store.recents.isEmpty ? "Landmarks" : "Recents")).font(
          MapTheme.font(13, bold: true)
        ).foregroundStyle(.gray).padding(14)
        ForEach(store.recents.isEmpty ? MapPlace.landmarks : store.recents) { place in
          PlaceRow(place: place) {
            store.select(place)
            searching = false
            searchFocused = false
          }
        }
      }
    }.background(Color(white: 0.97)).accessibilityIdentifier("search-results")
  }
}

struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    Path { p in
      p.move(to: .zero)
      p.addLine(to: CGPoint(x: rect.width, y: 0))
      p.addLine(to: CGPoint(x: rect.midX, y: rect.height))
      p.closeSubpath()
    }
  }
}
