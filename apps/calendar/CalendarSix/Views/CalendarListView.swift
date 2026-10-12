import SwiftUI

struct CalendarListView: View {
  let store: CalendarStore
  @Binding var selectedDate: Date
  @Binding var query: String
  let open: (EventOccurrence) -> Void
  @FocusState private var searching: Bool
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        HStack {
          Image(systemName: "magnifyingglass").foregroundStyle(Color(white: 0.55))
          TextField(L10n.text("Search"), text: $query).focused($searching).submitLabel(.search)
            .accessibilityIdentifier("search-events")
          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(Color(white: 0.55))
            }
            .accessibilityLabel(L10n.text("Clear Search")).accessibilityIdentifier("clear-search")
          }
        }.padding(.horizontal, 10).frame(height: 33).background(
          .white, in: RoundedRectangle(cornerRadius: 17)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 17).stroke(.black.opacity(0.25), lineWidth: 1)
            .allowsHitTesting(false)
        }
        if searching {
          Button(L10n.text("Cancel")) {
            query = ""
            searching = false
          }.buttonStyle(ClassicCalendarButtonStyle())
        }
      }.padding(8).background { CalendarMetal() }
      let events = listedEvents
      if events.isEmpty {
        CalendarEmpty(title: query.isEmpty ? "No Events" : "No Results")
      } else {
        ScrollView {
          LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(groups(events), id: \.date) { group in
              Section {
                ForEach(group.events) { occurrence in
                  CalendarEventRow(
                    occurrence: occurrence, source: store.source(occurrence.event.calendarID),
                    open: { open(occurrence) })
                }
              } header: {
                Text(CalendarFormat.date(group.date, template: "EEEE MMMM d yyyy"))
                  .font(.custom("HelveticaNeue-Bold", size: 14, relativeTo: .subheadline))
                  .foregroundStyle(.white).shadow(color: .black.opacity(0.5), radius: 0, y: -1)
                  .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(
                    .vertical, 5
                  )
                  .background(
                    LinearGradient(
                      colors: [
                        Color(red: 0.68, green: 0.72, blue: 0.78),
                        Color(red: 0.50, green: 0.56, blue: 0.65),
                      ], startPoint: .top, endPoint: .bottom)
                  )
                  .accessibilityAddTraits(.isHeader)
              }
            }
          }
        }.accessibilityIdentifier("event-list").scrollDismissesKeyboard(.interactively)
      }
    }.background(.white)
  }
  private var listedEvents: [EventOccurrence] {
    let start =
      query.isEmpty
      ? store.calendar.startOfDay(for: selectedDate)
      : store.calendar.date(byAdding: .year, value: -1, to: selectedDate)!
    let end = store.calendar.date(byAdding: .year, value: 1, to: selectedDate)!
    return store.occurrences(in: DateInterval(start: start, end: end), query: query)
  }
  private func groups(_ items: [EventOccurrence]) -> [(date: Date, events: [EventOccurrence])] {
    let grouped = Dictionary(grouping: items) { store.calendar.startOfDay(for: $0.start) }
    return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
  }
}
