import AppKit
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    let recordingState = RecordingState()

    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private let overlayController = OverlayWindowController()
    private var eventTap: CFMachPort?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()
        setupGlobalHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        // Request speech recognition permission
        SpeechRecognizer.requestAuthorization { granted in
            if !granted {
                self.recordingState.error = "Speech recognition permission denied"
            }
        }

        // Check accessibility permission (needed for global hotkey + paste)
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            print("Accessibility permission needed — a prompt should appear.")
        }
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotkey() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: globalKeyHandler,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Accessibility permission may be needed.")
            // Retry after a delay (user may be granting permission)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.setupGlobalHotkey()
            }
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Recording Toggle

    func toggleRecording() {
        if recordingState.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        recordingState.transcriptionText = ""
        recordingState.error = nil
        recordingState.isRecording = true
        recordingState.startTimer()

        // Set up speech recognizer callbacks
        speechRecognizer.onPartialResult = { [weak self] text in
            DispatchQueue.main.async {
                self?.recordingState.transcriptionText = text
            }
        }
        speechRecognizer.onFinalResult = { [weak self] text in
            DispatchQueue.main.async {
                self?.recordingState.transcriptionText = text
            }
        }
        speechRecognizer.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.recordingState.error = error
            }
        }

        // Start speech recognition and get the buffer handler
        let appendBuffer = speechRecognizer.startRecognition()

        // Feed audio buffers to the recognizer
        audioRecorder.bufferHandler = appendBuffer

        do {
            try audioRecorder.start()
        } catch {
            recordingState.error = error.localizedDescription
            recordingState.isRecording = false
            recordingState.stopTimer()
            return
        }

        // Show overlay
        overlayController.show(state: recordingState)
    }

    private func stopRecording() {
        recordingState.isRecording = false
        recordingState.stopTimer()

        audioRecorder.stop()
        speechRecognizer.stopRecognition()

        // Dismiss overlay
        overlayController.dismiss()

        // Auto-paste the transcription
        let finalText = recordingState.transcriptionText
        PasteService.pasteText(finalText)
    }
}

// MARK: - Global Event Tap Callback

private func globalKeyHandler(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown, let userInfo else {
        return Unmanaged.passRetained(event)
    }

    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    // Cmd+Shift+Space: keyCode 49 = Space
    let hasCmd = flags.contains(.maskCommand)
    let hasShift = flags.contains(.maskShift)
    let isSpace = keyCode == 49

    if hasCmd && hasShift && isSpace {
        let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
        DispatchQueue.main.async {
            delegate.toggleRecording()
        }
        return nil // Consume the event
    }

    return Unmanaged.passRetained(event)
}
