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
        lastPartialText = ""
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
                    self.lastPartialText = text
                    self.onFinalResult?(text)
                } else {
                    self.lastPartialText = text
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

    /// Gracefully stop recognition and wait for the final result.
    /// Calls `completion` on the main queue with the final text (or current best text on timeout).
    func stopRecognition(completion: @escaping (String) -> Void) {
        guard let recognitionRequest, recognitionTask != nil else {
            completion("")
            return
        }

        // Signal end-of-audio so the recognizer delivers a final result
        recognitionRequest.endAudio()
        self.recognitionRequest = nil

        var completed = false
        let complete: (String) -> Void = { [weak self] text in
            guard !completed else { return }
            completed = true
            self?.recognitionTask = nil
            DispatchQueue.main.async { completion(text) }
        }

        // Listen for the final result
        let previousFinal = onFinalResult
        onFinalResult = { text in
            complete(text)
            // Restore in case caller reuses this instance
            previousFinal?(text)
        }

        // Timeout: if no final result within 3 seconds, use whatever we have
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard !completed else { return }
            // Cancel to clean up, then deliver what we have
            self?.recognitionTask?.cancel()
            self?.recognitionTask = nil
            self?.onFinalResult = previousFinal
            completion(self?.lastPartialText ?? "")
        }
    }

    /// Fire-and-forget stop (used for cancellation)
    func cancelRecognition() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    private(set) var lastPartialText: String = ""
}
