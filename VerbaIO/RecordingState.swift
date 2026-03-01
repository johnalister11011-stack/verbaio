import Foundation
import Observation

@Observable
final class RecordingState {
    var isRecording = false
    var transcriptionText = ""
    var duration: TimeInterval = 0
    var error: String?

    private var timer: Timer?

    func startTimer() {
        duration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.duration += 0.1
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
