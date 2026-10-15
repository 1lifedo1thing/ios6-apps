import Foundation
import Observation

@Observable @MainActor
final class PhotoBrowseState {
  private struct Position: Codable {
    let id: String
    let date: Date
  }
  private var positions: [String: Position] = [:]
  private let file: URL

  init(directory: URL, demo: Bool) {
    file = directory.appendingPathComponent(demo ? "demo-positions.json" : "library-positions.json")
    if let data = try? Data(contentsOf: file),
      let positions = try? JSONDecoder().decode([String: Position].self, from: data)
    {
      self.positions = positions
    }
  }

  func anchor(in items: [PhotoItem], albumID: String, latest: Bool) -> String? {
    guard let position = positions[albumID] else {
      return (latest ? items.last : items.first)?.id
    }
    if items.contains(where: { $0.id == position.id }) { return position.id }
    // Deleted or no-longer-authorized assets resolve to the next surviving date.
    return items.first(where: { $0.date >= position.date })?.id ?? items.last?.id
  }

  func remember(_ item: PhotoItem, albumID: String) {
    positions[albumID] = Position(id: item.id, date: item.date)
  }

  func save() {
    guard let data = try? JSONEncoder().encode(positions) else { return }
    try? data.write(to: file, options: .atomic)
  }
}
