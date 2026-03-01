import AppKit
import CoreGraphics

enum PasteService {
    private static var savedClipboard: String?

    static func pasteText(_ text: String) {
        guard !text.isEmpty else { return }

        // Save current clipboard contents for restoration
        savedClipboard = NSPasteboard.general.string(forType: .string)

        // Copy transcription to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            simulatePaste()

            // Restore original clipboard after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                restoreClipboard()
            }
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v' key
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private static func restoreClipboard() {
        guard let saved = savedClipboard else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(saved, forType: .string)
        savedClipboard = nil
    }
}
