import SwiftUI
import AppKit

struct RecordingOverlayView: View {
    let state: RecordingState
    var onStop: () -> Void
    var onCancel: () -> Void

    @State private var dotOpacity: Double = 1.0

    private var dotColor: Color {
        switch state.phase {
        case .idle: return .gray
        case .recording: return .red
        case .processing: return .blue
        case .done: return .green
        }
    }

    private var statusText: String {
        switch state.phase {
        case .idle: return "Initializing..."
        case .recording: return "Recording"
        case .processing: return "Processing..."
        case .done: return "Done"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .opacity(state.phase == .recording ? dotOpacity : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            dotOpacity = 0.3
                        }
                    }

                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text(state.formattedDuration)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(state.transcriptionText.isEmpty ? "Listening..." : state.transcriptionText)
                .font(.system(size: 14))
                .foregroundStyle(state.transcriptionText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(6)

            HStack(spacing: 12) {
                Spacer()

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onStop) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                        Text("Stop & Paste")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}

final class OverlayWindowController {
    private var window: NSWindow?
    private var windowDelegate: WindowCloseDelegate?

    func show(state: RecordingState, onStop: @escaping () -> Void, onCancel: @escaping () -> Void) {
        guard window == nil else { return }

        let view = RecordingOverlayView(state: state, onStop: onStop, onCancel: onCancel)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 140)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 140),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "verba.io"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.backgroundColor = .windowBackgroundColor
        window.hasShadow = true
        window.contentView = hostingView
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        // Close button cancels the recording
        let closeDelegate = WindowCloseDelegate(onClose: onCancel)
        self.windowDelegate = closeDelegate
        window.delegate = closeDelegate

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 190
            let y = screenFrame.midY + 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func dismiss() {
        window?.delegate = nil
        window?.close()
        window = nil
        windowDelegate = nil
    }
}

final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
