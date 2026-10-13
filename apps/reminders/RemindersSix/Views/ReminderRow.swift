import SwiftUI

struct ReminderRow: View {
  let item: ReminderItem
  let editing: Bool
  let writable: Bool
  let toggle: () -> Void
  let open: () -> Void
  let delete: () -> Void
  let move: (Int) -> Void
  @State private var revealDelete = false
  @State private var dragging = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        Button {
          if editing { revealDelete.toggle() } else { toggle() }
        } label: {
          Group {
            if editing {
              Image(systemName: "minus.circle.fill").foregroundStyle(
                Color(red: 0.78, green: 0.08, blue: 0.1)
              )
              .font(.system(size: 22)).shadow(color: .white, radius: 0, y: 1)
            } else {
              ClassicCheckbox(checked: item.completed)
            }
          }.frame(width: 47).frame(minHeight: 50).contentShape(Rectangle())
        }.buttonStyle(.plain)
          .accessibilityLabel(
            L10n.format(
              editing ? "Delete %@" : (item.completed ? "Mark %@ incomplete" : "Complete %@"),
              item.title)
          )
          .accessibilityIdentifier("complete-\(item.id)").disabled(!writable)

        Button {
          if !dragging { open() }
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
              if !item.priority.mark.isEmpty {
                Text(item.priority.mark).foregroundStyle(Classic.red).font(
                  Classic.font(16, bold: true))
              }
              Text(item.title).font(Classic.font(18)).foregroundStyle(Classic.ink)
                .multilineTextAlignment(.leading)
            }
            if !item.subtitle().isEmpty {
              Text(item.subtitle()).font(Classic.font(13)).foregroundStyle(
                item.due.map { $0 < Date() && !item.completed } == true
                  ? Classic.red.opacity(0.8) : Classic.muted
              )
              .multilineTextAlignment(.leading)
            }
            if !item.notes.isEmpty {
              Text(item.notes).font(Classic.font(13)).foregroundStyle(Classic.muted).lineLimit(2)
                .multilineTextAlignment(.leading)
            }
          }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12).padding(
            .vertical, 12
          )
          .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("reminder-\(item.id)")
          .accessibilityLabel(item.title)
          .accessibilityValue(
            [item.subtitle(), item.notes].filter { !$0.isEmpty }.joined(separator: ", "))
        if revealDelete && writable {
          Button(L10n.text("Delete"), action: delete).buttonStyle(
            ClassicButtonStyle(silver: true, danger: true)
          ).padding(.trailing, 6)
        } else {
          Button {
            if !dragging { open() }
          } label: {
            Image(systemName: editing ? "line.3.horizontal" : "chevron.right")
              .font(.system(size: editing ? 19 : 16, weight: .bold)).foregroundStyle(
                Color(white: 0.62)
              )
              .shadow(color: .white.opacity(0.8), radius: 0, y: 1)
              .frame(width: 36).frame(minHeight: 44).contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityLabel(
            L10n.text("Details"))
        }
      }
      DottedRule()
    }
    .overlay { MarginRules() }
    .contentShape(Rectangle())
    .simultaneousGesture(
      DragGesture(minimumDistance: 30).onChanged { _ in dragging = true }.onEnded { value in
        if value.translation.width < -50 && abs(value.translation.height) < 30 && writable {
          revealDelete = true
        }
        if value.translation.width > 50 { revealDelete = false }
        Task {
          try? await Task.sleep(for: .milliseconds(200))
          dragging = false
        }
      }, including: editing ? .subviews : .all
    )
    .contextMenu {
      if !editing {
        Button(L10n.text("Details"), action: open)
        if writable {
          Button(L10n.text(item.completed ? "Mark Incomplete" : "Complete"), action: toggle)
          Button(L10n.text("Move up")) { move(-1) }
          Button(L10n.text("Move down")) { move(1) }
          Button(L10n.text("Delete"), role: .destructive, action: delete)
        }
      }
    }
    .accessibilityAction(named: L10n.text("Move up")) { move(-1) }
    .accessibilityAction(named: L10n.text("Move down")) { move(1) }
    .onChange(of: editing) {
      revealDelete = false
      dragging = false
    }
  }
}
