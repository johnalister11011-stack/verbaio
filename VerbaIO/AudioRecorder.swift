import AVFoundation

final class AudioRecorder {
    private let audioEngine = AVAudioEngine()
    private var isRunning = false

    var bufferHandler: ((AVAudioPCMBuffer) -> Void)?

    func start() throws {
        guard !isRunning else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            throw AudioRecorderError.invalidFormat
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.bufferHandler?(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
    }
}

enum AudioRecorderError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format from microphone"
        }
    }
}
