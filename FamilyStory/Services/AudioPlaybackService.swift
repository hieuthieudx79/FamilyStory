import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func toggle(url: URL) {
        if isPlaying {
            pause()
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Không tìm thấy tệp âm thanh trên thiết bị."
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.delegate = self
            audio.prepareToPlay()
            guard audio.play() else { throw PlaybackError.couldNotPlay }

            player = audio
            duration = audio.duration
            currentTime = audio.currentTime
            isPlaying = true
            errorMessage = nil
            startTimer()
        } catch {
            errorMessage = "Không thể phát bản ghi: \(error.localizedDescription)"
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func stop() {
        player?.stop()
        player = nil
        currentTime = 0
        pause()
    }

    func seek(to value: Double) {
        guard let player else { return }
        player.currentTime = min(max(0, value), player.duration)
        currentTime = player.currentTime
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying {
                    self.pause()
                }
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentTime = duration
        pause()
    }

    private enum PlaybackError: Error {
        case couldNotPlay
    }
}

func timeLabel(_ time: TimeInterval) -> String {
    let seconds = max(0, Int(time))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
