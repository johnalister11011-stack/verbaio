import AppKit
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    let recordingState = RecordingState()
    let hotkeySettings = HotkeySettings()

    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private let overlayController = OverlayWindowController()
    fileprivate var eventTap: CFMachPort?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()
        setupKeyMonitors()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
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
            NSLog("VerbaIO: Accessibility permission needed")
        }
    }

    // MARK: - Key Monitors

    private func setupKeyMonitors() {
        // Global monitor catches keys when other apps are focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor catches keys when our app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }

        // Also set up CGEvent tap for consuming hotkey globally (NSEvent global monitor can't consume)
        setupEventTap()
    }

    private func setupEventTap() {
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
            NSLog("VerbaIO: CGEvent tap failed, using NSEvent monitors only")
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // Returns true if the event was handled
    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = Int64(event.keyCode)

        // If listening for a new hotkey, capture it
        if hotkeySettings.isListeningForNewHotkey {
            hotkeySettings.keyCode = keyCode
            let relevantMods: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let mods = event.modifierFlags.intersection(relevantMods)
            var cgFlags = CGEventFlags(rawValue: 0)
            if mods.contains(.command) { cgFlags.insert(.maskCommand) }
            if mods.contains(.shift) { cgFlags.insert(.maskShift) }
            if mods.contains(.option) { cgFlags.insert(.maskAlternate) }
            if mods.contains(.control) { cgFlags.insert(.maskControl) }
            hotkeySettings.modifierFlags = cgFlags
            hotkeySettings.isListeningForNewHotkey = false
            return true
        }

        // Build CGEventFlags from NSEvent modifier flags
        let mods = event.modifierFlags
        var cgFlags = CGEventFlags(rawValue: 0)
        if mods.contains(.command) { cgFlags.insert(.maskCommand) }
        if mods.contains(.shift) { cgFlags.insert(.maskShift) }
        if mods.contains(.option) { cgFlags.insert(.maskAlternate) }
        if mods.contains(.control) { cgFlags.insert(.maskControl) }

        // Check hotkey match
        if hotkeySettings.matches(keyCode: keyCode, flags: cgFlags) {
            toggleRecording()
            return true
        }

        // Escape cancels
        if keyCode == 53 && recordingState.isRecording {
            cancelRecording()
            return true
        }

        return false
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

// MARK: - CGEvent Tap Callback (for consuming the hotkey so it doesn't type in apps)

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

    // Re-enable tap if macOS disabled it
    if type == .tapDisabledByTimeout {
        if let tap = delegate.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // Consume the hotkey so it doesn't type ']' in the focused app
    if delegate.hotkeySettings.matches(keyCode: keyCode, flags: flags) {
        // The NSEvent global monitor will handle the actual action
        // We just consume the event here so the character doesn't get typed
        DispatchQueue.main.async {
            delegate.toggleRecording()
        }
        return nil
    }

    // Consume escape during recording
    if keyCode == 53 && delegate.recordingState.isRecording {
        DispatchQueue.main.async {
            delegate.cancelRecording()
        }
        return nil
    }

    return Unmanaged.passRetained(event)
}
