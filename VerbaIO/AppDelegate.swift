import AppKit
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    let recordingState = RecordingState()
    let hotkeySettings = HotkeySettings()

    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private let overlayController = OverlayWindowController()
    fileprivate var eventTap: CFMachPort?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()
        // Delay hotkey setup slightly to allow accessibility permission to take effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.setupGlobalHotkey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        SpeechRecognizer.requestAuthorization { granted in
            if !granted {
                self.recordingState.error = "Speech recognition permission denied"
            }
        }

        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            print("Accessibility permission needed — a prompt should appear.")
        }
    }

    // MARK: - Global Hotkey

    func setupGlobalHotkey() {
        // Clean up existing tap
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }

        // Listen for keyDown and tapDisabledByTimeout
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: globalKeyHandler,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Retrying in 3s...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.setupGlobalHotkey()
            }
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Event tap created successfully")
    }

    // MARK: - Recording Toggle

    func toggleRecording() {
        if recordingState.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func cancelRecording() {
        guard recordingState.isRecording else { return }

        recordingState.wasCancelled = true
        recordingState.isRecording = false
        recordingState.phase = .idle
        recordingState.stopTimer()

        audioRecorder.stop()
        speechRecognizer.stopRecognition()

        overlayController.dismiss()
        NSSound.beep()
    }

    private func startRecording() {
        recordingState.transcriptionText = ""
        recordingState.error = nil
        recordingState.wasCancelled = false
        recordingState.isRecording = true
        recordingState.phase = .recording
        recordingState.startTimer()

        if let sound = NSSound(named: "Tink") {
            sound.play()
        }

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

        let appendBuffer = speechRecognizer.startRecognition()
        audioRecorder.bufferHandler = appendBuffer

        do {
            try audioRecorder.start()
        } catch {
            recordingState.error = error.localizedDescription
            recordingState.isRecording = false
            recordingState.phase = .idle
            recordingState.stopTimer()
            return
        }

        overlayController.show(
            state: recordingState,
            onStop: { [weak self] in self?.stopRecording() },
            onCancel: { [weak self] in self?.cancelRecording() }
        )
    }

    private func stopRecording() {
        guard recordingState.isRecording else { return }

        recordingState.phase = .processing
        recordingState.isRecording = false
        recordingState.stopTimer()

        audioRecorder.stop()
        speechRecognizer.stopRecognition()

        if let sound = NSSound(named: "Pop") {
            sound.play()
        }

        let finalText = recordingState.transcriptionText

        recordingState.phase = .done

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.overlayController.dismiss()
            self?.recordingState.phase = .idle
            PasteService.pasteText(finalText)
        }
    }
}

// MARK: - Global Event Tap Callback

private func globalKeyHandler(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passRetained(event)
    }

    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()

    // Re-enable the tap if macOS disabled it due to timeout
    if type == .tapDisabledByTimeout {
        if let tap = delegate.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Event tap re-enabled after timeout")
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // If listening for a new hotkey, capture it
    if delegate.hotkeySettings.isListeningForNewHotkey {
        DispatchQueue.main.async {
            delegate.hotkeySettings.keyCode = keyCode
            let relevantMask: UInt64 = CGEventFlags.maskCommand.rawValue
                | CGEventFlags.maskShift.rawValue
                | CGEventFlags.maskAlternate.rawValue
                | CGEventFlags.maskControl.rawValue
            delegate.hotkeySettings.modifierFlags = CGEventFlags(rawValue: flags.rawValue & relevantMask)
            delegate.hotkeySettings.isListeningForNewHotkey = false
        }
        return nil
    }

    // Check if the pressed key matches the configured hotkey
    if delegate.hotkeySettings.matches(keyCode: keyCode, flags: flags) {
        DispatchQueue.main.async {
            delegate.toggleRecording()
        }
        return nil
    }

    // Escape cancels active recording
    if keyCode == 53 && delegate.recordingState.isRecording {
        DispatchQueue.main.async {
            delegate.cancelRecording()
        }
        return nil
    }

    return Unmanaged.passRetained(event)
}
