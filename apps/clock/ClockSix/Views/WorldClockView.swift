import SwiftUI

struct WorldClockView: View {
  let store: ClockStore
  let editing: Bool
  var onEdit: () -> Void
  var onAdd: () -> Void
  var body: some View {
    VStack(spacing: 0) {
      ClockNavigationBar(
        title: "World Clock", left: editing ? "Done" : "Edit", right: "+", onLeft: onEdit,
        onRight: onAdd)
      GeometryReader { geometry in
        ZStack(alignment: .top) {
          WorldMapArtwork().frame(
            height: min(geometry.size.width * 0.55, geometry.size.height * 0.55)
          )
          .padding(.top, min(CGFloat(store.cities.count) * 100, geometry.size.height * 0.45))
          if store.cities.isEmpty {
            Text(L10n.text("No World Clocks")).font(ClockTheme.font(21, bold: true))
              .foregroundStyle(.white.opacity(0.8)).padding(.top, 80)
          }
          ScrollView {
            LazyVStack(spacing: 0) {
              ForEach(store.cities) { city in
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                  WorldClockRow(
                    city: city, date: timeline.date, editing: editing,
                    delete: { store.removeCity(city.id) },
                    up: { store.moveCity(city.id, by: -1) },
                    down: { store.moveCity(city.id, by: 1) })
                }
              }
            }
          }.accessibilityIdentifier("world-list")
        }
      }
    }
  }
}

struct WorldClockRow: View {
  let city: ClockCity
  let date: Date
  let editing: Bool
  var delete: () -> Void
  var up: () -> Void
  var down: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    HStack(spacing: 6) {
      if editing {
        Button(action: delete) {
          Image(systemName: "minus.circle.fill").font(.system(size: 24)).foregroundStyle(
            Color(hex: 0xC42D32))
        }
        .frame(width: 44, height: 44).accessibilityLabel(
          L10n.text("Delete") + " " + city.displayName()
        )
        .accessibilityIdentifier("delete-city-" + city.name)
      }
      Text(city.displayName()).font(ClockTheme.font(17, bold: true)).foregroundStyle(.black)
        .lineLimit(2).minimumScaleFactor(0.75).frame(maxWidth: .infinity, alignment: .leading)
      AnalogClock(date: date, zone: city.timeZone).frame(
        width: editing ? 64 : 78, height: editing ? 64 : 78)
      VStack(alignment: .trailing, spacing: 3) {
        Text(ClockFormat.time(date, zone: city.timeZone)).font(ClockTheme.font(26, bold: true))
          .lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(.black)
        Text(ClockFormat.day(date, zone: city.timeZone)).font(ClockTheme.font(15, bold: true))
          .foregroundStyle(Color(hex: 0x59595B))
      }.frame(maxWidth: .infinity, alignment: .trailing)
      if editing {
        VStack(spacing: 0) {
          Button(action: up) { Image(systemName: "chevron.up").frame(width: 44, height: 44) }
            .accessibilityLabel(L10n.text("Move up") + " " + city.displayName())
          Button(action: down) { Image(systemName: "chevron.down").frame(width: 44, height: 44) }
            .accessibilityLabel(L10n.text("Move down") + " " + city.displayName())
        }.buttonStyle(.plain).font(.system(size: 14, weight: .bold)).foregroundStyle(.gray).frame(
          width: 44)
      }
    }.padding(.horizontal, 10).frame(minHeight: typeSize.isAccessibilitySize ? 132 : 100)
      .background(ClockTheme.row).overlay(alignment: .bottom) { SilverSeparator() }
      .accessibilityElement(children: editing ? .contain : .combine)
      .accessibilityIdentifier("city-" + city.name)
  }
}

struct CitySearchView: View {
  let store: ClockStore
  var close: () -> Void
  @State private var query = ""
  private var results: [ClockCity] {
    ClockCity.catalog.filter { $0.matches(query) }.sorted {
      $0.displayName().localizedStandardCompare($1.displayName()) == .orderedAscending
    }
  }
  var body: some View {
    ZStack {
      PinstripeBackground()
      VStack(spacing: 0) {
        ClockNavigationBar(title: "Choose a City", right: "Cancel", onRight: close)
        HStack {
          Image(systemName: "magnifyingglass").foregroundStyle(.gray)
          TextField(L10n.text("Search"), text: $query).textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(.black).accessibilityIdentifier("city-search")
          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
            }.accessibilityLabel(L10n.text("Clear search"))
          }
        }.padding(8).background(.white).clipShape(RoundedRectangle(cornerRadius: 8)).padding(8)
          .background(Color(hex: 0xADB9CA))
        ScrollView {
          LazyVStack(spacing: 0) {
            if results.isEmpty {
              Text(L10n.text("No cities found")).font(ClockTheme.font(18)).foregroundStyle(.gray)
                .padding(30)
            }
            ForEach(results) { city in
              Button {
                store.addCity(city)
                close()
              } label: {
                HStack {
                  Text(city.displayName()).font(ClockTheme.font(19, bold: true)).foregroundStyle(
                    .black)
                  Spacer()
                  if store.cities.contains(where: { $0.id == city.id }) {
                    Image(systemName: "checkmark").foregroundStyle(ClockTheme.value)
                  }
                }.padding(.horizontal, 16).frame(minHeight: 48).frame(maxWidth: .infinity)
                  .contentShape(Rectangle())
              }.buttonStyle(.plain).accessibilityIdentifier("search-city-" + city.name)
              SilverSeparator()
            }
          }.background(.white)
        }
      }
    }
  }
}
