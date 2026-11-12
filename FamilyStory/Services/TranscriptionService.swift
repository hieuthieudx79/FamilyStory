import Foundation
import Speech

@MainActor
final class TranscriptionService {
    enum TranscriptionError: LocalizedError {
        case permissionDenied
        case languageUnavailable
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Bạn chưa cấp quyền nhận dạng giọng nói cho Family Story."
            case .languageUnavailable:
                return "Thiết bị hoặc ngôn ngữ này chưa hỗ trợ nhận dạng giọng nói hoàn toàn trên thiết bị."
            case .emptyResult:
                return "Chưa nhận diện được nội dung trong bản ghi."
            }
        }
    }

    private var recognitionTask: SFSpeechRecognitionTask?

    func transcribe(url: URL, localeIdentifier: String = "vi-VN") async throws -> String {
        let authorization = await requestAuthorization()
        guard authorization == .authorized else {
            throw TranscriptionError.permissionDenied
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.languageUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation

        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask?.cancel()
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    continuation.resume(throwing: TranscriptionError.emptyResult)
                } else {
                    continuation.resume(returning: text)
                }
            }
        }
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
