import AppKit

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

        // Simulate Cmd+V via AppleScript (more reliable than CGEvent)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let script = NSAppleScript(source: """
                tell application "System Events"
                    keystroke "v" using command down
                end tell
            """)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error {
                NSLog("VerbaIO: Paste error: %@", error)
            }

            // Restore original clipboard after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                restoreClipboard()
            }
        }
    }

    private static func restoreClipboard() {
        guard let saved = savedClipboard else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(saved, forType: .string)
        savedClipboard = nil
    }
}
