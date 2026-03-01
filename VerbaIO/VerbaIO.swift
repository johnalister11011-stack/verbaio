import SwiftUI

@main
struct VerbaIO: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("verba.io", systemImage: "waveform") {
            VStack(alignment: .leading, spacing: 4) {
                if appDelegate.recordingState.isRecording {
                    Text("Recording... \(appDelegate.recordingState.formattedDuration)")
                        .font(.system(size: 13, weight: .medium))
                    Divider()
                }

                if let error = appDelegate.recordingState.error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Divider()
                }

                Button(appDelegate.recordingState.isRecording ? "Stop & Paste" : "Start Recording") {
                    appDelegate.toggleRecording()
                }

                if appDelegate.recordingState.isRecording {
                    Button("Cancel Recording") {
                        appDelegate.cancelRecording()
                    }
                }

                Divider()

                Text("Hotkey: \(appDelegate.hotkeySettings.displayString)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Divider()

                Button("Quit verba.io") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(4)
        }
    }
}
