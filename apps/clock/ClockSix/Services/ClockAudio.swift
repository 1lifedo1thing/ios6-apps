import AVFoundation
import MediaPlayer

@MainActor
final class ClockAudio {
  static let shared = ClockAudio()
  private var player: AVAudioPlayer?
  private var musicPlayer: MPMusicPlayerController?
  func playAlarm(_ alarm: ClockAlarm) {
    if let song = alarm.song, MPMediaLibrary.authorizationStatus() == .authorized {
      let query = MPMediaQuery.songs()
      query.addFilterPredicate(
        MPMediaPropertyPredicate(
          value: song.persistentID, forProperty: MPMediaItemPropertyPersistentID))
      if let item = query.items?.first, !item.isCloudItem {
        stop()
        musicPlayer = .applicationMusicPlayer
        musicPlayer?.repeatMode = .one
        musicPlayer?.setQueue(with: MPMediaItemCollection(items: [item]))
        musicPlayer?.play()
        return
      }
    }
    play(alarm.sound, loop: true)
  }
  func play(_ sound: ClockSound, loop: Bool = false) {
    stop()
    guard let file = sound.filename,
      let url = Bundle.main.url(forResource: file, withExtension: nil)
    else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)
      player = try AVAudioPlayer(contentsOf: url)
      player?.numberOfLoops = loop ? -1 : 0
      player?.play()
    } catch { player = nil }
  }
  func stop() {
    player?.stop()
    player = nil
    musicPlayer?.stop()
    musicPlayer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  func stopOtherPlayback() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
    try? session.setActive(false)
  }
}
