import Photos
import SwiftUI

struct PhotosRootView: View {
  @Bindable var library: PhotoLibrary
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @State private var tab = "Albums"
  @State private var albumID: String?
  @State private var selectedID: String?
  @State private var gridFocus: PhotoGridFocus?
  @State private var editing = false
  @State private var selection: Set<String> = []
  @State private var nameDialog = false
  @State private var name = ""
  @State private var renaming: PhotoAlbum?
  @State private var deletingAlbum: PhotoAlbum?
  @State private var deleteItems = false
  @State private var choosingAlbum = false
  @State private var addingToAlbum: String?
  @State private var shareItems: [PhotoItem] = []
  @State private var showSettings = false
  @State private var pendingAsset: String?
  @State private var sheet: SharePayload?

  private var album: PhotoAlbum? { library.albums.first { $0.id == albumID } }
  private var visibleItems: [PhotoItem] {
    addingToAlbum == nil ? album?.items ?? [] : library.allItems
  }
  private var chosen: [PhotoItem] { visibleItems.filter { selection.contains($0.id) } }
  private var showingViewer: Bool { selectedID != nil && album != nil }

  var body: some View {
    ZStack {
      if showingViewer {
        Color.black.ignoresSafeArea()
      } else {
        Color(white: 0.22).ignoresSafeArea()
      }
      content.accessibilityHidden(hasOverlay).allowsHitTesting(!hasOverlay)
      overlays
    }
    .preferredColorScheme(.dark)
    .environment(\.locale, AppLanguage.current.locale)
    .task {
      await library.activate()
      resolvePendingAsset()
      #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--device-smoke") {
          if let id = await DeviceLibraryCheck.run(library) {
            albumID = "roll"
            selectedID = id
          }
        }
      #endif
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active {
        Task {
          await library.activate()
          resolvePendingAsset()
        }
      } else {
        library.browsing.save()
      }
    }
    .onChange(of: library.albums) {
      if let id = selectedID, !visibleItems.contains(where: { $0.id == id }) { selectedID = nil }
      resolvePendingAsset()
    }
    .onOpenURL { url in
      guard url.scheme == "photossix", url.host == "library" else { return }
      tab = "Albums"
      albumID = "roll"
      selectedID = nil
      editing = false
      pendingAsset = PhotoLink.assetID(from: url)
      Task {
        await library.openSystemLibrary()
        resolvePendingAsset()
      }
    }
    .sheet(item: $sheet) { payload in ActivitySheet(payload: payload) }
    .fullScreenCover(isPresented: $showSettings) {
      PhotoSettingsView(library: library) { showSettings = false }
    }
  }

  @ViewBuilder private var content: some View {
    ZStack {
      VStack(spacing: 0) {
        navigation
        if library.authorization == .limited {
          Button(L10n.text("Selected Photos Access • Manage")) { showSettings = true }
            .font(PhotosTheme.font(12)).frame(maxWidth: .infinity, minHeight: 30).background(.white)
        }
        if !library.canRead {
          permissionView
        } else if let album {
          grid(album)
        } else if tab == "Places" {
          PlacesView(library: library) { id in
            albumID = "roll"
            selectedID = id
          }
        } else {
          albumsList
        }
        if album != nil && editing { selectionToolbar } else { tabBar }
      }.opacity(showingViewer ? 0 : 1).allowsHitTesting(!showingViewer)
        .accessibilityHidden(showingViewer)
      if let album, let selectedID {
        PhotoViewer(library: library, albumID: album.id, initialID: selectedID) { id in
          if let id, id != selectedID {
            gridFocus = PhotoGridFocus(id: id)
            if let item = album.items.first(where: { $0.id == id }) {
              library.browsing.remember(item, albumID: album.id)
            }
          }
          library.browsing.save()
          self.selectedID = nil
        }.id(selectedID)
      }
    }
  }

  private var navigation: some View {
    PhotoNavigation(
      title: addingToAlbum != nil ? L10n.text("Add Photos") : album?.displayTitle ?? L10n.text(tab)
    ) {
      if albumID != nil {
        Button {
          back()
        } label: {
          HStack(spacing: 3) {
            Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
            Text(L10n.text(addingToAlbum != nil ? "Cancel" : "Albums"))
          }
        }.buttonStyle(PhotoButtonStyle()).accessibilityIdentifier("albums-back")
      } else if tab == "Albums", library.canRead {
        HStack(spacing: 5) {
          Button {
            renaming = nil
            name = ""
            nameDialog = true
          } label: {
            Image(systemName: "plus").font(.system(size: 18, weight: .bold))
          }
          .buttonStyle(PhotoButtonStyle()).frame(minHeight: 44).accessibilityLabel(
            L10n.text("New Album")
          ).accessibilityIdentifier("new-album")
          Button {
            openCamera()
          } label: {
            Image(systemName: "camera.fill").font(.system(size: 15))
          }
          .buttonStyle(PhotoButtonStyle()).frame(minHeight: 44).accessibilityLabel(
            L10n.text("Open Camera")
          ).accessibilityIdentifier("open-camera")
        }
      } else {
        PhotoTool(symbol: "gearshape", label: "Settings", identifier: "photo-settings") {
          showSettings = true
        }
      }
    } trailing: {
      if library.canRead && tab != "Places" {
        Button(L10n.text(addingToAlbum != nil || editing ? "Done" : "Edit")) { editAction() }
          .buttonStyle(PhotoButtonStyle(primary: editing)).accessibilityIdentifier("edit-done")
      } else {
        Color.clear.frame(width: 44)
      }
    }
  }

  private var demoBanner: some View {
    Text(L10n.text("Demo Library • Original Illustrations"))
      .font(PhotosTheme.font(11)).foregroundStyle(Color(white: 0.35))
      .frame(maxWidth: .infinity).padding(.vertical, 4).background(Color.white.opacity(0.6))
      .accessibilityIdentifier("demo-library")
  }

  private var albumsList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(library.albums.filter { tab == "Photo Stream" ? $0.shared : !$0.shared }) { album in
          albumRow(album)
        }
        if library.isDemo && tab == "Albums" { demoBanner }
        if tab == "Photo Stream" {
          VStack(spacing: 12) {
            Image(systemName: "cloud").font(.system(size: 50)).foregroundStyle(.gray)
            Text(L10n.text("Photo Stream")).font(PhotosTheme.font(21, bold: true))
            Text(
              L10n.text(
                "My Photo Stream has been retired by Apple. Available iCloud Shared Albums appear here with full Photos access."
              )
            )
            .font(PhotosTheme.font(15)).multilineTextAlignment(.center)
          }.foregroundStyle(PhotosTheme.ink).padding(28).frame(maxWidth: .infinity)
        }
      }
    }.background { AlbumRules() }
  }

  private func albumRow(_ album: PhotoAlbum) -> some View {
    HStack(spacing: 0) {
      if editing && album.editable {
        Button {
          deletingAlbum = album
        } label: {
          Image(systemName: "minus.circle.fill").font(.system(size: 25)).foregroundStyle(.red)
            .frame(width: 44, height: 56)
        }.buttonStyle(.plain).accessibilityLabel(L10n.text("Delete Album"))
      }
      Button {
        if editing && album.editable {
          renaming = album
          name = album.title
          nameDialog = true
        } else {
          albumID = album.id
          editing = false
          selection = []
        }
      } label: {
        HStack(spacing: 10) {
          if let item = album.items.first {
            PhotoThumbnail(item: item, library: library, size: 55)
          } else {
            Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(.gray)
              .frame(width: 55, height: 55).background(Color(white: 0.92))
          }
          HStack(spacing: 7) {
            Text(album.displayTitle).font(PhotosTheme.font(18, bold: true)).foregroundStyle(.black)
              .lineLimit(2)
            Text("(\(album.items.count))").font(PhotosTheme.font(17)).foregroundStyle(
              Color(white: 0.54))
          }
          Spacer(minLength: 5)
          Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(
            Color(white: 0.57)
          ).padding(.trailing, 12)
        }.frame(minHeight: 56).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier("album-" + album.id)
        .accessibilityLabel(album.displayTitle + ", " + L10n.itemCount(album.items.count))
      if editing && album.editable {
        VStack(spacing: 0) {
          Button {
            library.moveAlbum(album, by: -1)
          } label: {
            Image(systemName: "chevron.up").frame(width: 44, height: 28)
          }.accessibilityLabel(L10n.text("Move Up"))
          Button {
            library.moveAlbum(album, by: 1)
          } label: {
            Image(systemName: "chevron.down").frame(width: 44, height: 28)
          }.accessibilityLabel(L10n.text("Move Down"))
        }.buttonStyle(.plain).foregroundStyle(.gray)
      }
    }.background(.white).overlay(alignment: .bottom) { Color(white: 0.79).frame(height: 0.5) }
  }

  private func grid(_ album: PhotoAlbum) -> some View {
    let positionKey = addingToAlbum == nil ? album.id : "picker"
    return PhotoAlbumGrid(
      library: library, items: visibleItems, positionKey: positionKey,
      latest: addingToAlbum == nil && (album.id == "roll" || album.id == "videos"),
      editing: editing, selection: $selection, focus: gridFocus,
      open: { selectedID = $0 }, camera: openCamera
    ).id(positionKey)
  }

  private var selectionToolbar: some View {
    HStack(spacing: 8) {
      if addingToAlbum == nil {
        Button(L10n.text("Share")) { shareItems = chosen }.buttonStyle(PhotoButtonStyle()).disabled(
          selection.isEmpty)
        Spacer()
        Button(L10n.text("Add To")) { choosingAlbum = true }.buttonStyle(PhotoButtonStyle())
          .disabled(selection.isEmpty)
        Spacer()
        Button(L10n.text(album?.editable == true ? "Remove" : "Delete")) { deleteItems = true }
          .buttonStyle(PhotoButtonStyle(destructive: true)).disabled(
            selection.isEmpty || album?.shared == true)
      } else {
        Text(L10n.format("%d selected", selection.count)).font(PhotosTheme.font(16, bold: true))
          .foregroundStyle(.white)
        Spacer()
      }
    }.padding(.horizontal, 10).frame(height: 48).background(
      PhotosTheme.chrome, ignoresSafeAreaEdges: [])
  }

  private var tabBar: some View {
    HStack(spacing: 0) {
      tabButton("Albums", symbol: "rectangle.on.rectangle")
      tabButton("Photo Stream", symbol: "cloud")
      tabButton("Places", symbol: "globe.europe.africa.fill")
    }.frame(height: 50).background(PhotosTheme.black, ignoresSafeAreaEdges: [])
      .overlay(alignment: .top) { Color.white.opacity(0.4).frame(height: 1) }
  }

  private func tabButton(_ title: String, symbol: String) -> some View {
    Button {
      tab = title
      albumID = nil
      editing = false
    } label: {
      VStack(spacing: 2) {
        Image(systemName: symbol).font(.system(size: 24, weight: .medium))
          .foregroundStyle(
            tab == title ? Color(red: 0.32, green: 0.73, blue: 1) : Color(white: 0.65)
          )
          .shadow(color: tab == title ? .blue.opacity(0.7) : .black, radius: tab == title ? 5 : 0)
        Text(L10n.text(title)).font(PhotosTheme.font(10, bold: true)).foregroundStyle(
          tab == title ? .white : .gray)
      }.frame(maxWidth: .infinity, minHeight: 48)
        .background(tab == title ? Color.white.opacity(0.08) : .clear)
    }.buttonStyle(.plain).accessibilityIdentifier("tab-" + title).accessibilityAddTraits(
      tab == title ? [.isSelected] : [])
  }

  private var permissionView: some View {
    VStack(spacing: 18) {
      Spacer()
      Image(systemName: "photo.on.rectangle").font(.system(size: 65)).foregroundStyle(
        Color(red: 0.35, green: 0.45, blue: 0.58))
      Text(L10n.text("Your Photos, Just Like Before")).font(PhotosTheme.font(23, bold: true))
        .multilineTextAlignment(.center)
      Text(
        L10n.text(
          "Browse the photos and videos on your iPhone. CameraSix captures appear here after saving to Photos."
        )
      )
      .font(PhotosTheme.font(16)).multilineTextAlignment(.center)
      Button(
        L10n.text(library.authorization == .notDetermined ? "Open Photo Library" : "Open Settings")
      ) {
        if library.authorization == .notDetermined {
          Task { await library.activate(request: true) }
        } else {
          openURL(URL(string: UIApplication.openSettingsURLString)!)
        }
      }.buttonStyle(PhotoButtonStyle(primary: true)).frame(minHeight: 44).accessibilityIdentifier(
        "allow-library")
      Spacer()
    }.padding(28).foregroundStyle(PhotosTheme.ink).frame(maxWidth: .infinity).background(
      Color.white, ignoresSafeAreaEdges: [])
  }

  private var hasOverlay: Bool {
    nameDialog || deletingAlbum != nil || deleteItems || choosingAlbum || !shareItems.isEmpty
      || library.message != nil || library.busy
  }

  @ViewBuilder private var overlays: some View {
    if nameDialog { albumNamePanel }
    if let deletingAlbum {
      ClassicPhotoAlert(
        title: "Delete Album?", text: "Deleting an album keeps its photos in Camera Roll.",
        confirm: "Delete", cancel: "Cancel"
      ) {
        perform { try await library.deleteAlbum(deletingAlbum) }
        self.deletingAlbum = nil
      } dismiss: {
        self.deletingAlbum = nil
      }
    }
    if deleteItems {
      ClassicPhotoAlert(
        title: album?.editable == true ? "Remove from Album?" : "Delete from Photo Library?",
        text: album?.editable == true
          ? "These items will stay in Camera Roll."
          : "These items will be deleted from the system photo library on all synced devices.",
        confirm: "Delete", cancel: "Cancel"
      ) {
        let items = chosen
        let source = album?.editable == true ? album : nil
        perform {
          try await library.delete(items, from: source)
          selection = []
        }
        deleteItems = false
      } dismiss: {
        deleteItems = false
      }
    }
    if choosingAlbum { albumChooser }
    if !shareItems.isEmpty {
      ClassicSharePanel(
        items: shareItems, library: library, dismiss: { shareItems = [] },
        share: { payload in
          shareItems = []
          sheet = payload
        })
    }
    if library.busy {
      Color.black.opacity(0.35).ignoresSafeArea()
      ProgressView(L10n.text("Saving…")).padding(24).background(
        .white, in: RoundedRectangle(cornerRadius: 8))
    }
    if let message = library.message {
      ClassicPhotoAlert(title: "Photos", text: message) { library.message = nil }
    }
  }

  private var albumNamePanel: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      VStack(spacing: 14) {
        Text(L10n.text(renaming == nil ? "New Album" : "Rename Album")).font(
          PhotosTheme.font(20, bold: true))
        TextField(L10n.text("Album Name"), text: $name).font(PhotosTheme.font(17)).padding(10)
          .background(.white).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 5))
          .accessibilityIdentifier("album-name").submitLabel(.done).onSubmit { saveName() }
        HStack {
          Button(L10n.text("Cancel")) { nameDialog = false }.buttonStyle(PhotoButtonStyle())
          Spacer()
          Button(L10n.text("Save")) { saveName() }.buttonStyle(PhotoButtonStyle(primary: true))
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("save-album")
        }.frame(minHeight: 44)
      }.foregroundStyle(.white).padding(20).frame(maxWidth: 320).background(PhotosTheme.chrome)
        .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(
          RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.6), lineWidth: 2)
        ).padding()
    }.accessibilityAddTraits(.isModal)
  }

  private var albumChooser: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      VStack(spacing: 0) {
        PhotoNavigation(title: L10n.text("Add To Album")) {
          Button(L10n.text("Cancel")) { choosingAlbum = false }.buttonStyle(PhotoButtonStyle())
        } trailing: {
          EmptyView()
        }
        ScrollView {
          VStack(spacing: 0) {
            ForEach(library.albums.filter(\.editable)) { target in
              Button(target.title) {
                let items = chosen
                choosingAlbum = false
                perform {
                  try await library.add(items, to: target)
                  selection = []
                  editing = false
                }
              }.font(PhotosTheme.font(19, bold: true)).foregroundStyle(PhotosTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 52).background(.white).overlay(
                  alignment: .bottom
                ) { Color.gray.opacity(0.4).frame(height: 1) }
            }
            if !library.albums.contains(where: \.editable) {
              Text(L10n.text("Create an album first.")).padding(22)
            }
          }
        }.frame(maxHeight: 280).background(.white)
      }.clipShape(RoundedRectangle(cornerRadius: 9)).padding(20)
    }.accessibilityAddTraits(.isModal)
  }

  private func editAction() {
    if let targetID = addingToAlbum, let target = library.albums.first(where: { $0.id == targetID })
    {
      let items = chosen
      perform {
        try await library.add(items, to: target)
        albumID = targetID
        addingToAlbum = nil
        editing = false
        selection = []
      }
    } else {
      editing.toggle()
      selection = []
    }
  }
  private func saveName() {
    let value = name
    let previous = renaming
    nameDialog = false
    perform {
      if let previous {
        try await library.rename(previous, to: value)
      } else {
        let id = try await library.createAlbum(value)
        albumID = "roll"
        addingToAlbum = id
        editing = true
        selection = []
      }
    }
  }
  private func back() {
    if addingToAlbum != nil {
      albumID = addingToAlbum
      addingToAlbum = nil
      editing = false
      selection = []
    } else {
      albumID = nil
      editing = false
      selection = []
    }
  }
  private func perform(_ work: @escaping @MainActor () async throws -> Void) {
    library.busy = true
    Task {
      defer { library.busy = false }
      do { try await work() } catch { library.message = error.localizedDescription }
    }
  }
  private func openCamera() {
    openURL(PhotoLink.camera) { accepted in
      if !accepted { library.message = PhotoFailure.noCamera.localizedDescription }
    }
  }
  private func resolvePendingAsset() {
    guard let pendingAsset, library.canRead else { return }
    if library.allItems.contains(where: { $0.id == pendingAsset }) {
      albumID = "roll"
      selectedID = pendingAsset
      self.pendingAsset = nil
    } else {
      self.pendingAsset = nil
      library.message = L10n.text(
        "The photo is not available. With limited access, include it in your selection in Settings."
      )
    }
  }
}

private struct AlbumRules: View {
  var body: some View {
    Canvas { context, size in
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
      for y in stride(from: 56.0, through: size.height, by: 56) {
        context.fill(
          Path(CGRect(x: 0, y: y - 0.5, width: size.width, height: 0.5)),
          with: .color(Color(white: 0.82)))
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}
