import AVFoundation
import Foundation

@MainActor
final class AudioPlaybackService: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var errorMessage: String?
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func toggle(url: URL) {
        if isPlaying { pause(); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.prepareToPlay()
            guard audio.play() else { throw PlaybackError.failed }
            player = audio
            duration = audio.duration
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let player = self.player else { return }
                    self.currentTime = player.currentTime
                    if !player.isPlaying { self.pause() }
                }
            }
        } catch { errorMessage = "Không thể phát bản ghi: \(error.localizedDescription)" }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func seek(to value: Double) {
        player?.currentTime = value
        currentTime = value
    }

    private enum PlaybackError: Error { case failed }
}

func timeLabel(_ time: TimeInterval) -> String {
    let seconds = max(0, Int(time))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}