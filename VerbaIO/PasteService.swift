import AppKit
import CoreGraphics

enum PasteService {
    private static var savedClipboard: String?

    static func pasteText(_ text: String) {
        guard !text.isEmpty else { return }

        // Save current clipboard for restoration
        savedClipboard = NSPasteboard.general.string(forType: .string)

        // Put transcription on clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V via CGEvent
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            simulatePaste()

            // Restore original clipboard after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                restoreClipboard()
            }
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key down: Cmd+V (virtual key 0x09 = 'v')
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    private static func restoreClipboard() {
        guard let saved = savedClipboard else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(saved, forType: .string)
        savedClipboard = nil
    }
}
