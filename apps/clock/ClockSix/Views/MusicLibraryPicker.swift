import MediaPlayer
import SwiftUI

struct MusicLibraryPicker: UIViewControllerRepresentable {
  @Environment(\.dismiss) private var dismiss
  var onPick: (AlarmSong) -> Void
  func makeUIViewController(context: Context) -> MPMediaPickerController {
    let picker = MPMediaPickerController(mediaTypes: .music)
    picker.allowsPickingMultipleItems = false
    picker.showsCloudItems = false
    picker.showsItemsWithProtectedAssets = false
    picker.prompt = L10n.text("Pick a song")
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ controller: MPMediaPickerController, context: Context) {
    context.coordinator.parent = self
  }
  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
  final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
    var parent: MusicLibraryPicker
    init(parent: MusicLibraryPicker) { self.parent = parent }
    func mediaPicker(
      _ mediaPicker: MPMediaPickerController, didPickMediaItems collection: MPMediaItemCollection
    ) {
      if let item = collection.items.first {
        parent.onPick(
          AlarmSong(persistentID: item.persistentID, title: item.title ?? L10n.text("Song")))
      }
      parent.dismiss()
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) { parent.dismiss() }
  }
}
