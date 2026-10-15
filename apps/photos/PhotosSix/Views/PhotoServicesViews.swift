import MapKit
import MessageUI
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum PhotoShareService { case more, mail, message }

struct SharePayload: Identifiable {
  let id = UUID()
  let urls: [URL]
  var service: PhotoShareService = .more
}

struct ActivitySheet: UIViewControllerRepresentable {
  let payload: SharePayload
  @Environment(\.dismiss) private var dismiss
  func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }
  func makeUIViewController(context: Context) -> UIViewController {
    if payload.service == .mail, MFMailComposeViewController.canSendMail() {
      let controller = MFMailComposeViewController()
      controller.mailComposeDelegate = context.coordinator
      for url in payload.urls {
        if let data = try? Data(contentsOf: url) {
          controller.addAttachmentData(
            data,
            mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
              ?? "application/octet-stream",
            fileName: url.lastPathComponent)
        }
      }
      return controller
    }
    if payload.service == .message, MFMessageComposeViewController.canSendText(),
      MFMessageComposeViewController.canSendAttachments()
    {
      let controller = MFMessageComposeViewController()
      controller.messageComposeDelegate = context.coordinator
      for url in payload.urls {
        controller.addAttachmentURL(url, withAlternateFilename: url.lastPathComponent)
      }
      return controller
    }
    return UIActivityViewController(activityItems: payload.urls, applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIViewController, context: Context) {}
  final class Coordinator: NSObject, MFMailComposeViewControllerDelegate,
    MFMessageComposeViewControllerDelegate
  {
    let dismiss: () -> Void
    init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
    func mailComposeController(
      _ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult,
      error: Error?
    ) { dismiss() }
    func messageComposeViewController(
      _ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult
    ) { dismiss() }
  }
}

struct ClassicSharePanel: View {
  let items: [PhotoItem]
  let library: PhotoLibrary
  let dismiss: () -> Void
  let share: (SharePayload) -> Void
  @State private var busy = false
  @State private var error: String?
  var body: some View {
    ZStack(alignment: .bottom) {
      Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { if !busy { dismiss() } }
      VStack(spacing: 14) {
        Text(L10n.itemCount(items.count)).font(PhotosTheme.font(14, bold: true)).foregroundStyle(
          .white.opacity(0.85))
        HStack(spacing: 15) {
          tile("envelope.fill", "Mail", colors: [.cyan, .blue]) { export(.mail) }
          tile(
            "message.fill", "Message", colors: [.green, Color(red: 0.04, green: 0.43, blue: 0.05)]
          ) { export(.message) }
          tile("square.and.arrow.up", "More…", colors: [Color(white: 0.75), Color(white: 0.35)]) {
            export()
          }
        }
        HStack(spacing: 15) {
          tile("doc.on.doc.fill", "Copy", colors: [Color(white: 0.83), Color(white: 0.45)]) {
            copy()
          }
          tile("printer.fill", "Print", colors: [Color(white: 0.7), Color(white: 0.22)]) {
            printPhotos()
          }
          tile(
            "photo", "Wallpaper",
            colors: [
              Color(red: 0.45, green: 0.55, blue: 0.75), Color(red: 0.20, green: 0.28, blue: 0.45),
            ]
          ) {
            error = L10n.text(
              "To use a photo as wallpaper, open Settings > Wallpaper > Add New Wallpaper and choose it from Photos."
            )
          }
        }
        if busy { ProgressView(L10n.text("Preparing…")).tint(.white).foregroundStyle(.white) }
        Button(L10n.text("Cancel"), action: dismiss).buttonStyle(PhotoButtonStyle()).frame(
          maxWidth: .infinity, minHeight: 44
        ).disabled(busy)
      }.padding(18).frame(maxWidth: .infinity).background(PhotosTheme.black)
      if let error { ClassicPhotoAlert(title: "Photos", text: error) { self.error = nil } }
    }.accessibilityAddTraits(.isModal)
  }
  private func tile(
    _ symbol: String, _ title: String, colors: [Color], action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Image(systemName: symbol).font(.system(size: 31, weight: .medium)).foregroundStyle(.white)
          .shadow(color: .black.opacity(0.4), radius: 1, y: 1).frame(width: 62, height: 62)
          .background(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
          .overlay(alignment: .top) { Color.white.opacity(0.25).frame(height: 30) }
          .clipShape(RoundedRectangle(cornerRadius: 11))
          .overlay(
            RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.35), lineWidth: 1)
          ).shadow(radius: 2, y: 2)
        Text(L10n.text(title)).font(PhotosTheme.font(12, bold: true)).foregroundStyle(.white)
          .lineLimit(1)
      }.frame(maxWidth: .infinity)
    }.buttonStyle(.plain).disabled(busy).accessibilityLabel(L10n.text(title))
  }
  private func export(_ service: PhotoShareService = .more) {
    if service == .mail && !MFMailComposeViewController.canSendMail() {
      error = L10n.text("Mail is not configured. Use More… to choose another app.")
      return
    }
    if service == .message
      && (!MFMessageComposeViewController.canSendText()
        || !MFMessageComposeViewController.canSendAttachments())
    {
      error = L10n.text("Messages is unavailable. Use More… to choose another app.")
      return
    }
    busy = true
    Task {
      defer { busy = false }
      do {
        let urls = try await library.export(items)
        if service == .mail {
          let total = urls.reduce(0) { count, url in
            count + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
          }
          guard total <= 20 * 1024 * 1024 else {
            error = L10n.text("Use More… to share large attachments.")
            return
          }
        }
        share(SharePayload(urls: urls, service: service))
      } catch {
        self.error = error.localizedDescription
      }
    }
  }
  private func copy() {
    busy = true
    Task {
      defer { busy = false }
      do {
        if items.allSatisfy({ !$0.isVideo }) {
          var images: [UIImage] = []
          for item in items { images.append(try await library.image(item)) }
          UIPasteboard.general.images = images
          dismiss()
        } else {
          UIPasteboard.general.urls = try await library.export(items)
          dismiss()
        }
      } catch { self.error = error.localizedDescription }
    }
  }
  private func printPhotos() {
    guard items.allSatisfy({ !$0.isVideo }) else {
      error = L10n.text("Select photos to print.")
      return
    }
    busy = true
    Task {
      defer { busy = false }
      do {
        let urls = try await library.export(items)
        let printController = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .photo
        info.jobName = L10n.text("Photos")
        printController.printInfo = info
        printController.printingItems = urls
        printController.present(animated: true) { _, _, failure in
          if let failure { error = failure.localizedDescription }
        }
      } catch { self.error = error.localizedDescription }
    }
  }
}

struct PlaceCluster: Identifiable {
  let id: String
  let items: [PhotoItem]
  var coordinate: CLLocationCoordinate2D { items[0].coordinate! }
  static func clusters(_ items: [PhotoItem]) -> [Self] {
    let located = items.filter { $0.coordinate != nil }
    return Dictionary(grouping: located) { item in
      String(format: "%.2f,%.2f", item.latitude!, item.longitude!)
    }.map { PlaceCluster(id: $0.key, items: $0.value) }.sorted { $0.id < $1.id }
  }
}

struct PlacesView: View {
  let library: PhotoLibrary
  let open: (String) -> Void
  @State private var satellite = false
  @State private var selected: PlaceCluster?
  private var clusters: [PlaceCluster] { PlaceCluster.clusters(library.allItems) }
  var body: some View {
    ZStack(alignment: .bottom) {
      if clusters.isEmpty {
        VStack(spacing: 16) {
          Image(systemName: "mappin.and.ellipse").font(.system(size: 58)).foregroundStyle(.gray)
          Text(L10n.text("No Location Information")).font(PhotosTheme.font(20, bold: true))
          Text(L10n.text("Photos with saved locations appear on this map.")).font(
            PhotosTheme.font(16)
          ).multilineTextAlignment(.center)
        }.foregroundStyle(PhotosTheme.ink).padding(28).frame(
          maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Map(initialPosition: .automatic) {
          ForEach(clusters) { cluster in
            Annotation(L10n.itemCount(cluster.items.count), coordinate: cluster.coordinate) {
              Button {
                selected = cluster
              } label: {
                VStack(spacing: 0) {
                  PhotoThumbnail(item: cluster.items.last!, library: library, size: 42).padding(3)
                    .background(.white)
                    .overlay(Rectangle().stroke(.gray, lineWidth: 1)).shadow(radius: 2)
                  Image(systemName: "mappin").font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.red)
                }
              }.buttonStyle(.plain).accessibilityLabel(L10n.itemCount(cluster.items.count))
            }
          }
        }.mapStyle(satellite ? .imagery : .standard)
        VStack {
          Spacer()
          if let selected {
            HStack {
              Text(L10n.itemCount(selected.items.count)).font(PhotosTheme.font(17, bold: true))
              Spacer()
              Button(L10n.text("View Photos")) { open(selected.items[0].id) }.buttonStyle(
                PhotoButtonStyle())
              Button {
                self.selected = nil
              } label: {
                Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
              }.accessibilityLabel(L10n.text("Close"))
            }.padding(10).background(.white).shadow(radius: 5)
          }
          HStack {
            Spacer()
            Button(L10n.text(satellite ? "Map" : "Satellite")) { satellite.toggle() }
              .buttonStyle(PhotoButtonStyle()).padding(10)
          }
        }
      }
    }.accessibilityIdentifier("places-map")
  }
}

struct PhotoSettingsView: View {
  let library: PhotoLibrary
  let dismiss: () -> Void
  @Environment(\.openURL) private var openURL
  @State private var limited = false
  var body: some View {
    ZStack {
      PhotoStripes().ignoresSafeArea()
      VStack(spacing: 0) {
        PhotoNavigation(title: L10n.text("Photos"), titleIdentifier: "photo-settings-title") {
          EmptyView()
        } trailing: {
          Button(L10n.text("Done"), action: dismiss).buttonStyle(PhotoButtonStyle())
            .accessibilityIdentifier("photo-settings-done")
        }
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("Photo Library")).font(PhotosTheme.font(18, bold: true))
            Text(
              L10n.text(
                library.isDemo
                  ? "Demo Library • Original Illustrations"
                  : library.authorization == .limited
                    ? "Selected Photos Access"
                    : library.canRead ? "Full Photo Library Access" : "No Photo Library Access")
            )
            .font(PhotosTheme.font(16)).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 8))
            if library.authorization == .limited && !library.isDemo {
              Button(L10n.text("Manage Selected Photos")) { limited = true }.buttonStyle(
                PhotoButtonStyle()
              ).frame(minHeight: 44)
            }
            Button(L10n.text("Open Settings")) {
              openURL(URL(string: UIApplication.openSettingsURLString)!)
            }.buttonStyle(PhotoButtonStyle()).frame(minHeight: 44)
            Text(L10n.text("CameraSix")).font(PhotosTheme.font(18, bold: true))
            Text(
              L10n.text(
                "CameraSix and PhotosSix share the system photo library. Enable Save to Photos in CameraSix. Local-only captures remain in CameraSix until saved."
              )
            )
            .font(PhotosTheme.font(15))
            Button(L10n.text("Open Camera")) {
              openURL(PhotoLink.camera) { success in
                if !success {
                  library.message = PhotoFailure.noCamera.localizedDescription
                  dismiss()
                }
              }
            }.buttonStyle(PhotoButtonStyle()).frame(minHeight: 44).accessibilityIdentifier(
              "open-camera")
            Text(L10n.text("Language")).font(PhotosTheme.font(18, bold: true))
            Text(
              L10n.text(
                "Uses the system or app language: English and Simplified Chinese. Chinese variants use Simplified Chinese; other languages use English."
              )
            )
            .font(PhotosTheme.font(15))
          }.foregroundStyle(Color(white: 0.20)).padding(20)
        }
      }
    }.preferredColorScheme(.light).sheet(isPresented: $limited) { LimitedPicker() }
  }
}

private struct LimitedPicker: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UIViewController { LimitedController() }
  func updateUIViewController(_ controller: UIViewController, context: Context) {}
  private final class LimitedController: UIViewController {
    private var shown = false
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      guard !shown else { return }
      shown = true
      PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self) { [weak self] _ in
        self?.dismiss(animated: true)
      }
    }
  }
}
