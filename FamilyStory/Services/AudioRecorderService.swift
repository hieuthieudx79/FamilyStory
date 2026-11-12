import AVFoundation
import Foundation

@MainActor
final class AudioRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var savedURL: URL?
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var timer: Timer?

    func requestPermissionAndStart() async {
        let session = AVAudioApplication.shared
        let granted = await session.requestRecordPermission()
        guard granted else {
            errorMessage = "Hãy cho phép Family Story sử dụng micro trong Cài đặt."
            return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try audioSession.setActive(true)

            let filename = "memory-\(UUID().uuidString).m4a"
            let url = ArchiveStorage.audioURL(filename: filename)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true
            guard newRecorder.record() else { throw AudioError.startFailed }
            recorder = newRecorder
            savedURL = url
            startedAt = .now
            accumulated = 0
            isRecording = true
            isPaused = false
            startTimer()
        } catch {
            errorMessage = "Không thể bắt đầu ghi âm: \(error.localizedDescription)"
        }
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        recorder?.pause()
        accumulated = elapsed
        isPaused = true
        timer?.invalidate()
    }

    func resume() {
        guard isRecording, isPaused else { return }
        guard recorder?.record() == true else {
            errorMessage = "Không thể tiếp tục bản ghi."
            return
        }
        startedAt = .now
        isPaused = false
        startTimer()
    }

    func finish() -> (URL, TimeInterval)? {
        guard let recorder, let url = savedURL else { return nil }
        recorder.stop()
        timer?.invalidate()
        let duration = max(elapsed, recorder.currentTime)
        self.recorder = nil
        isRecording = false
        isPaused = false
        elapsed = duration
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard FileManager.default.fileExists(atPath: url.path),
              (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 > 0 else {
            errorMessage = "Bản ghi chưa được lưu hợp lệ. Vui lòng thử lại."
            return nil
        }
        return (url, duration)
    }

    func discard() {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        if let savedURL { try? FileManager.default.removeItem(at: savedURL) }
        savedURL = nil
        elapsed = 0
        accumulated = 0
        isRecording = false
        isPaused = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = self.accumulated + (self.startedAt.map { Date.now.timeIntervalSince($0) } ?? 0)
            }
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { errorMessage = "Bản ghi bị gián đoạn. Hãy kiểm tra trước khi rời màn hình." }
    }

    private enum AudioError: Error { case startFailed }
}