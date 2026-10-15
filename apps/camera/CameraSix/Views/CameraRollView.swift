import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct CameraRollView: View {
  @ObservedObject var library: MediaLibrary
  @Environment(\.openURL) private var openURL
  let isDemo: Bool
  let dismiss: () -> Void
  @State private var selected: UUID?
  @State private var shareURL: URL?
  @State private var deleteItem: CapturedMedia?
  @State private var message: String?
  @State private var pickerOpen = false
  @State private var pickedItems: [PhotosPickerItem] = []
  @State private var importing = false
  @State private var openingPhotos = false
  @State private var editorOpen = false
  @State private var controlsVisible = true
  @State private var photoScale: CGFloat = 1

  private var current: CapturedMedia? { library.items.first { $0.id == selected } }

  var body: some View {
    ZStack {
      (selected == nil ? Color(white: 0.22) : Color.black).ignoresSafeArea()
      VStack(spacing: 0) {
        if controlsVisible || selected == nil {
          ClassicPhotoNavigation(
            title: selected == nil ? L10n.text("Camera Roll") : title,
            dark: selected != nil, accessibilityTitle: fullTitle
          ) {
            Button {
              if selected == nil {
                dismiss()
              } else {
                selected = nil
                photoScale = 1
              }
            } label: {
              HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                Text(L10n.text(selected == nil ? "Camera" : "Camera Roll"))
              }.lineLimit(1)
            }.buttonStyle(ClassicPhotoButtonStyle())
              .accessibilityIdentifier("navigation-back")
          } trailing: {
            HStack(spacing: 5) {
              Button(L10n.text("Photos")) { openPhotos() }
                .buttonStyle(ClassicPhotoButtonStyle())
                .frame(minHeight: 44).accessibilityIdentifier("open-photos").disabled(
                  openingPhotos)
              trailing
            }
          }
        }
        if let current { detail(current) } else { grid }
        if let current, controlsVisible { toolbar(current) }
      }
      if importing {
        Color.black.opacity(0.5).ignoresSafeArea()
        ProgressView(L10n.text("Importing…")).tint(.white).foregroundStyle(.white)
          .padding(24).background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 10))
      }
      if let deleteItem {
        ClassicCameraAlert(
          title: "Delete local copy?",
          message: "This removes the copy in Camera Roll. Photos library copies are kept.",
          confirm: "Delete", cancel: "Cancel"
        ) {
          do {
            try library.removeLocal(deleteItem)
            selected = nil
          } catch { message = "The item could not be deleted." }
          self.deleteItem = nil
        } dismiss: {
          self.deleteItem = nil
        }
      }
      if let message {
        ClassicCameraAlert(title: "Camera Roll", message: message, confirm: "OK") {
          self.message = nil
        }
      }
    }
    .preferredColorScheme(.dark)
    .photosPicker(
      isPresented: $pickerOpen, selection: $pickedItems, maxSelectionCount: 20,
      matching: .any(of: [.images, .videos])
    )
    .onChange(of: pickedItems) { Task { await importItems() } }
    .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
      if let shareURL { ShareController(url: shareURL) }
    }
    .fullScreenCover(isPresented: $editorOpen) {
      if let current {
        PhotoEditorView(url: library.url(for: current)) { data in
          if let data {
            Task {
              do {
                let item = try await library.addPhoto(data)
                selected = item.id
              } catch { message = "The photo could not be saved. Please check available storage." }
            }
          }
          editorOpen = false
        }
      }
    }
  }

  private var title: String {
    guard let index = library.items.firstIndex(where: { $0.id == selected }) else {
      return L10n.text("Camera Roll")
    }
    return L10n.format("%d / %d", index + 1, library.items.count)
  }

  private var fullTitle: String? {
    guard let index = library.items.firstIndex(where: { $0.id == selected }) else { return nil }
    return L10n.format("%d of %d", index + 1, library.items.count)
  }

  @ViewBuilder private var trailing: some View {
    if let current, current.kind != .video {
      Button(L10n.text("Edit")) { editorOpen = true }.buttonStyle(
        ClassicPhotoButtonStyle()
      )
      .frame(minHeight: 44).accessibilityIdentifier("edit-photo")
    } else if selected == nil {
      Button {
        pickerOpen = true
      } label: {
        Image(systemName: "plus").font(.system(size: 18, weight: .bold))
      }
      .buttonStyle(ClassicPhotoButtonStyle()).frame(minWidth: 44, minHeight: 44)
      .accessibilityLabel(L10n.text("Import from Photos"))
    }
  }

  private var grid: some View {
    Group {
      if library.items.isEmpty {
        VStack(spacing: 14) {
          Image(systemName: "photo.on.rectangle").font(.system(size: 46)).foregroundStyle(
            Color(white: 0.45))
          Text(L10n.text("No Photos or Videos")).font(CameraTheme.font(20, bold: true))
          Text(L10n.text("Photos and videos you take appear here.")).font(CameraTheme.font(16))
            .multilineTextAlignment(.center)
          Button(L10n.text("Import from Photos")) { pickerOpen = true }.buttonStyle(
            ClassicPhotoButtonStyle())
        }.foregroundStyle(Color(white: 0.3)).padding(25).frame(
          maxWidth: .infinity, maxHeight: .infinity)
      } else {
        GeometryReader { geometry in
          let columns = geometry.size.width > 600 ? 7 : 4
          let size = max(
            1, (geometry.size.width - 10 - CGFloat(columns - 1) * 4) / CGFloat(columns))
          ScrollView {
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
              spacing: 4
            ) {
              ForEach(library.items) { item in
                Button {
                  selected = item.id
                  controlsVisible = true
                } label: {
                  ZStack(alignment: .bottomTrailing) {
                    if let image = library.thumbnail(for: item) {
                      Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: size, height: size).clipped()
                    } else {
                      Color(white: 0.1)
                    }
                    if item.kind == .video {
                      Image(systemName: "video.fill").font(.system(size: 13)).padding(4).background(
                        .black.opacity(0.65))
                    } else if item.isHDR {
                      Text("HDR").font(CameraTheme.font(10, bold: true)).padding(3).background(
                        .black.opacity(0.6))
                    }
                  }
                  .frame(width: size, height: size).clipped().foregroundStyle(.white)
                }.buttonStyle(.plain)
                  .accessibilityLabel(
                    L10n.text(
                      item.kind == .video ? "Video" : item.kind == .panorama ? "Panorama" : "Photo")
                      + ", " + AppLanguage.current.timestamp(item.createdAt)
                  )
                  .accessibilityIdentifier("media-" + item.id.uuidString)
              }
            }.padding(5)
            Text(L10n.itemCount(library.items.count)).font(CameraTheme.font(16, bold: true))
              .foregroundStyle(Color(white: 0.4)).padding(16).accessibilityIdentifier("media-count")
          }
        }
      }
    }.background(Color.white, ignoresSafeAreaEdges: [])
  }

  @ViewBuilder private func detail(_ item: CapturedMedia) -> some View {
    if item.kind == .video {
      MoviePlayer(url: library.url(for: item)).id(item.id).frame(
        maxWidth: .infinity, maxHeight: .infinity
      )
      .accessibilityIdentifier("video-player")
    } else {
      GeometryReader { geometry in
        ZStack(alignment: .topLeading) {
          if let image = UIImage(contentsOfFile: library.url(for: item).path) {
            Image(uiImage: image).resizable().scaledToFit().scaleEffect(photoScale)
              .frame(width: geometry.size.width, height: geometry.size.height)
              .onTapGesture { controlsVisible.toggle() }
              .gesture(MagnifyGesture().onChanged { photoScale = max(1, min(4, $0.magnification)) })
              .simultaneousGesture(
                DragGesture(minimumDistance: 35).onEnded { value in
                  guard photoScale < 1.1,
                    abs(value.translation.width) > abs(value.translation.height)
                  else { return }
                  navigate(value.translation.width > 0 ? -1 : 1)
                }
              )
              .accessibilityLabel(L10n.text("Photo")).accessibilityIdentifier("photo-detail")
          }
          if item.isHDR && controlsVisible {
            Text("HDR").font(CameraTheme.font(13, bold: true)).padding(8).background(
              .black.opacity(0.5))
          }
        }
      }.clipped()
    }
  }

  private func toolbar(_ item: CapturedMedia) -> some View {
    HStack(spacing: 0) {
      toolbarButton("square.and.arrow.up", "Share", identifier: "share-media") {
        shareURL = library.url(for: item)
      }
      Spacer(minLength: 0)
      toolbarButton("chevron.left", "Previous", identifier: "previous-media") { navigate(-1) }
      toolbarButton("chevron.right", "Next", identifier: "next-media") { navigate(1) }
      Spacer(minLength: 0)
      toolbarButton(
        item.savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down", "Save to Photos",
        identifier: "save-photos"
      ) {
        Task {
          do {
            try await library.saveToPhotos(item)
            message = "Saved to Photos."
          } catch LibraryError.permissionDenied {
            message = "Allow Photos access in Settings to save this item."
          } catch { message = "Saving to Photos failed. Please try again." }
        }
      }
      toolbarButton("trash", "Delete", identifier: "delete-media") { deleteItem = item }
    }.padding(.horizontal, 7).frame(height: 44).foregroundStyle(.white)
      .background(ClassicPhotoChrome.black, ignoresSafeAreaEdges: [])
      .overlay(alignment: .top) { Color.white.opacity(0.25).frame(height: 1) }
  }

  private func toolbarButton(
    _ image: String, _ label: String, identifier: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: image).font(.system(size: 22, weight: .medium)).frame(width: 46, height: 44)
    }
    .buttonStyle(.plain).accessibilityLabel(L10n.text(label)).accessibilityIdentifier(identifier)
  }

  private func navigate(_ direction: Int) {
    guard let index = library.items.firstIndex(where: { $0.id == selected }) else { return }
    let next = index + direction
    if library.items.indices.contains(next) {
      selected = library.items[next].id
      photoScale = 1
    }
  }

  private func openPhotos() {
    guard UIApplication.shared.canOpenURL(library.photosURL(for: nil)) else {
      message = "Install PhotosSix to browse the system photo library."
      return
    }
    let item = current
    openingPhotos = true
    Task {
      defer { openingPhotos = false }
      do {
        if let item { try await library.saveToPhotos(item) }
        openURL(library.photosURL(for: item))
      } catch LibraryError.permissionDenied {
        message = "Allow Photos access in Settings to save this item."
      } catch {
        message = "Saving to Photos failed. Please try again."
      }
    }
  }

  private func importItems() async {
    guard !pickedItems.isEmpty else { return }
    importing = true
    defer {
      importing = false
      pickedItems = []
    }
    for item in pickedItems {
      do {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
          if let movie = try await item.loadTransferable(type: ImportedMovie.self) {
            _ = try await library.addVideo(movie.url)
          }
        } else if let data = try await item.loadTransferable(type: Data.self),
          let image = UIImage(data: data),
          let jpeg = ImageProcessing.upright(image, maxDimension: 4096).jpegData(
            compressionQuality: 0.95)
        {
          _ = try await library.addPhoto(jpeg)
        }
      } catch { message = "Some items could not be imported. Please try again." }
    }
  }
}

private struct ImportedMovie: Transferable {
  let url: URL
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .movie) { file in
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString + ".mov")
      try FileManager.default.copyItem(at: file.file, to: url)
      return Self(url: url)
    }
  }
}

private struct MoviePlayer: View {
  @State private var player: AVPlayer
  init(url: URL) { _player = State(initialValue: AVPlayer(url: url)) }
  var body: some View { VideoPlayer(player: player).onDisappear { player.pause() } }
}

private struct ShareController: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
