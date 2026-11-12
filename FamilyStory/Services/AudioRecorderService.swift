import AVFoundation
import Combine
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
    private var interruptionObserver: NSObjectProtocol?

    override init() {
        super.init()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }
    }

    func requestPermissionAndStart() async {
        guard !isRecording else { return }
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            errorMessage = "Hãy cho phép Family Story sử dụng micro trong Cài đặt."
            return
        }

        do {
            try ArchiveStorage.prepareDirectories()
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
            guard newRecorder.record() else { throw RecorderError.couldNotStart }

            recorder = newRecorder
            savedURL = url
            startedAt = .now
            accumulated = 0
            elapsed = 0
            isRecording = true
            isPaused = false
            errorMessage = nil
            startTimer()
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false)
            errorMessage = "Không thể bắt đầu ghi âm: \(error.localizedDescription)"
        }
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        recorder?.pause()
        accumulated = elapsed
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        guard isRecording, isPaused else { return }
        guard recorder?.record() == true else {
            errorMessage = "Không thể tiếp tục bản ghi. Bản ghi hiện tại vẫn được giữ lại."
            return
        }
        startedAt = .now
        isPaused = false
        errorMessage = nil
        startTimer()
    }

    func finish() -> (url: URL, duration: TimeInterval)? {
        guard let recorder, let url = savedURL else { return nil }
        let measuredDuration = max(elapsed, recorder.currentTime)
        recorder.stop()
        timer?.invalidate()
        timer = nil
        self.recorder = nil
        isRecording = false
        isPaused = false
        elapsed = measuredDuration
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard FileManager.default.fileExists(atPath: url.path), fileSize > 0 else {
            errorMessage = "Bản ghi chưa được lưu hợp lệ. Vui lòng thử lại."
            return nil
        }
        return (url, measuredDuration)
    }

    func discard() {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
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
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsed = self.accumulated + (self.startedAt.map { Date.now.timeIntervalSince($0) } ?? 0)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        if type == .began, isRecording, !isPaused {
            pause()
            errorMessage = "iOS đã tạm ngắt micro. Bản ghi được giữ lại; hãy nhấn tiếp tục khi sẵn sàng."
        } else if type == .ended, isRecording, isPaused {
            errorMessage = "Micro đã sẵn sàng. Nhấn tiếp tục để ghi âm tiếp."
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            errorMessage = "Bản ghi bị gián đoạn. Hãy kiểm tra tệp trước khi rời màn hình."
        }
    }

    private enum RecorderError: Error {
        case couldNotStart
    }
}
