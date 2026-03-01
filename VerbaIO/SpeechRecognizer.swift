import Speech

final class SpeechRecognizer {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onError: ((String) -> Void)?

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func startRecognition() -> ((AVAudioPCMBuffer) -> Void) {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest, let speechRecognizer, speechRecognizer.isAvailable else {
            onError?("Speech recognition is not available")
            return { _ in }
        }

        recognitionRequest.shouldReportPartialResults = true

        if #available(macOS 15, *) {
            recognitionRequest.addsPunctuation = true
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.onFinalResult?(text)
                } else {
                    self.onPartialResult?(text)
                }
            }

            if let error {
                // Ignore cancellation errors when we intentionally stop
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                    return
                }
                self.onError?(error.localizedDescription)
            }
        }

        return { [weak self] buffer in
            self?.recognitionRequest?.append(buffer)
        }
    }

    func stopRecognition() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        // Don't cancel — let the task deliver the final result.
        // It will clean itself up once isFinal arrives.
    }
}
