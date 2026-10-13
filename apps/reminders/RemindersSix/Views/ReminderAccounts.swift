import SwiftUI

struct ReminderAccounts: View {
  @Bindable var store: ReminderStore
  let close: () -> Void
  @State private var busy = false

  var body: some View {
    VStack(spacing: 0) {
      ClassicHeader(title: L10n.text("Accounts")) {
        Button(L10n.text("Back"), action: close).buttonStyle(ClassicButtonStyle())
          .accessibilityIdentifier("Close Accounts")
      } trailing: {
        Color.clear.frame(width: 62, height: 44).accessibilityHidden(true)
      }
      PaperCard {
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("On My iPhone")).font(Classic.font(14, bold: true))
              .foregroundStyle(Classic.muted)
            DetailGroup {
              DetailRow(
                title: "Lists", value: store.lists.filter { $0.systemID == nil }.count.formatted())
            }
            Text(
              L10n.text(
                store.isolated
                  ? "Preview data is separate from your saved reminders."
                  : "Local lists stay on this iPhone. Connected accounts use the system's Reminders sync."
              )
            )
            .font(Classic.font(14)).foregroundStyle(Classic.muted)
            .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text("System Reminders")).font(Classic.font(14, bold: true))
              .foregroundStyle(Classic.muted).padding(.top, 10)
            DetailGroup {
              DetailRow(
                title: "System Reminders",
                value: L10n.text(store.connected ? "Connected" : "Not Connected"))
              DetailLine()
              if store.connected {
                DetailRow(title: "Refresh System Reminders") {
                  Task { await store.refreshSystem() }
                }
                DetailLine()
                DetailRow(title: "Disconnect System Reminders") {
                  do { try store.disconnectSystem() } catch {
                    store.error = error.localizedDescription
                  }
                }
              } else {
                DetailRow(title: "Connect System Reminders") {
                  busy = true
                  Task {
                    defer { busy = false }
                    do { try await store.connectSystem() } catch {
                      store.error = error.localizedDescription
                    }
                  }
                }
              }
            }
            Text(
              L10n.text(
                store.connected
                  ? "Disconnecting keeps your system reminders intact."
                  : "Reminders reads and edits system reminders only when you choose to connect your accounts."
              )
            )
            .font(Classic.font(14)).foregroundStyle(Classic.muted)
            .fixedSize(horizontal: false, vertical: true)
            DetailGroup {
              DetailRow(title: "Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
              }
            }.padding(.top, 10)
          }.padding(15)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      }.padding(.horizontal, 7).padding(.top, 3).padding(.bottom, 8)
    }.environment(\.colorScheme, .light)
      .disabled(busy || store.loading)
      .overlay {
        if busy || store.loading {
          ProgressView().tint(Classic.ink).padding(25)
            .background(Classic.paper, in: RoundedRectangle(cornerRadius: 8))
        }
      }
      .accessibilityAction(.escape, close)
  }
}
