import SwiftUI

struct PhotoGridFocus: Equatable {
  let id: String
  let request = UUID()
}

struct PhotoAlbumGrid: View {
  let library: PhotoLibrary
  let items: [PhotoItem]
  let positionKey: String
  let latest: Bool
  let editing: Bool
  @Binding var selection: Set<String>
  let focus: PhotoGridFocus?
  let open: (String) -> Void
  let camera: () -> Void
  @State private var scrollID: String?

  init(
    library: PhotoLibrary, items: [PhotoItem], positionKey: String, latest: Bool,
    editing: Bool, selection: Binding<Set<String>>, focus: PhotoGridFocus?,
    open: @escaping (String) -> Void, camera: @escaping () -> Void
  ) {
    self.library = library
    self.items = items
    self.positionKey = positionKey
    self.latest = latest
    self.editing = editing
    _selection = selection
    self.focus = focus
    self.open = open
    self.camera = camera
    _scrollID = State(
      initialValue: library.browsing.anchor(in: items, albumID: positionKey, latest: latest))
  }

  var body: some View {
    GeometryReader { geometry in
      let count = geometry.size.width > 600 ? 7 : 4
      let side = floor((geometry.size.width - 10 - CGFloat(count - 1) * 4) / CGFloat(count))
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 4) {
          ForEach(rows(columns: count)) { row in
            HStack(spacing: 4) {
              ForEach(row.items) { item in
                Button {
                  if editing {
                    if selection.contains(item.id) {
                      selection.remove(item.id)
                    } else {
                      selection.insert(item.id)
                    }
                  } else {
                    library.browsing.save()
                    open(item.id)
                  }
                } label: {
                  ZStack(alignment: .bottomTrailing) {
                    PhotoThumbnail(item: item, library: library, size: side)
                    if selection.contains(item.id) {
                      Color.white.opacity(0.28)
                      Image(systemName: "checkmark.circle.fill").font(.system(size: 24))
                        .foregroundStyle(.white, .blue).shadow(radius: 2).padding(4)
                    }
                  }.frame(width: side, height: side)
                }.buttonStyle(.plain).id(item.id).accessibilityIdentifier("photo-" + item.id)
                  .accessibilityLabel(
                    L10n.text(item.isVideo ? "Video" : "Photo") + ", "
                      + AppLanguage.current.timestamp(item.date)
                  )
                  .accessibilityAddTraits(selection.contains(item.id) ? [.isSelected] : [])
              }
            }.frame(maxWidth: .infinity, alignment: .leading).id(row.id)
          }
        }.scrollTargetLayout().padding(5)
        Text(editing ? L10n.format("%d selected", selection.count) : L10n.itemCount(items.count))
          .font(PhotosTheme.font(17)).foregroundStyle(.gray).padding(18)
          .accessibilityIdentifier("photo-grid-count")
        if items.isEmpty {
          Text(L10n.text("No Photos or Videos")).font(PhotosTheme.font(20, bold: true))
            .foregroundStyle(.gray).padding(30)
          if !editing {
            Button(L10n.text("Take a Photo"), action: camera).buttonStyle(PhotoButtonStyle())
              .frame(minHeight: 44)
          }
        }
      }.scrollPosition(id: $scrollID, anchor: .top)
        .accessibilityIdentifier("photo-grid")
        .background(.white, ignoresSafeAreaEdges: [])
        .onAppear { scrollID = rowAnchor(for: scrollID, columns: count) }
        .onChange(of: count) { scrollID = rowAnchor(for: scrollID, columns: count) }
        .onChange(of: scrollID) { rememberPosition() }
        .onChange(of: focus) {
          if let focus { scrollID = rowAnchor(for: focus.id, columns: count) }
        }
        .onChange(of: items) {
          let anchor =
            items.contains(where: { $0.id == scrollID })
            ? scrollID
            : library.browsing.anchor(in: items, albumID: positionKey, latest: latest)
          scrollID = rowAnchor(for: anchor, columns: count)
        }
        .onDisappear {
          rememberPosition()
          library.browsing.save()
        }
    }
  }

  private struct Row: Identifiable {
    let id: String
    let items: [PhotoItem]
  }

  private func rows(columns: Int) -> [Row] {
    stride(from: 0, to: items.count, by: columns).map { start in
      Row(id: items[start].id, items: Array(items[start..<min(start + columns, items.count)]))
    }
  }

  private func rowAnchor(for id: String?, columns: Int) -> String? {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
    return items[(index / columns) * columns].id
  }

  private func rememberPosition() {
    if let item = items.first(where: { $0.id == scrollID }) {
      library.browsing.remember(item, albumID: positionKey)
    }
  }
}
