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

                Button("Toggle Recording (⌘⇧Space)") {
                    appDelegate.toggleRecording()
                }
                .keyboardShortcut(" ", modifiers: [.command, .shift])

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
