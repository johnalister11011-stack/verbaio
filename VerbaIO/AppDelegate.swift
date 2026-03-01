import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    let recordingState = RecordingState()
    let hotkeySettings = HotkeySettings()

    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private let overlayController = OverlayWindowController()
    private var hotkeyRef: EventHotKeyRef?
    private var localMonitor: Any?
    private var previousApp: NSRunningApplication?

    private static let hotkeyID = EventHotKeyID(signature: OSType(0x5642494F), // "VBIO"
                                                 id: 1)

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()
        installCarbonHotkeyHandler()
        registerHotkey()

        // Local monitor for when our own windows are focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 && self?.recordingState.isRecording == true {
                self?.cancelRecording()
                return nil
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotkey()
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
            NSLog("VerbaIO: Accessibility permission needed for auto-paste")
        }
    }

    // MARK: - Carbon Global Hotkey

    @discardableResult
    private func installCarbonHotkeyHandler() -> Bool {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyCallback,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            nil
        )
        return status == noErr
    }

    @discardableResult
    func registerHotkey() -> Bool {
        unregisterHotkey()

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkeySettings.keyCode,
            hotkeySettings.carbonModifiers,
            AppDelegate.hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            self.hotkeyRef = hotKeyRef
        }
        return status == noErr
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
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

        // Return focus to previous app
        previousApp?.activate()
        previousApp = nil

        NSSound.beep()
    }

    private func startRecording() {
        // Remember which app is currently focused BEFORE we show our window
        previousApp = NSWorkspace.shared.frontmostApplication

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

        // Dismiss overlay first
        overlayController.dismiss()

        // Re-activate the previous app so paste goes to the right place
        let targetApp = previousApp
        previousApp = nil

        // Give the previous app time to regain focus, then paste
        targetApp?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.recordingState.phase = .idle
            PasteService.pasteText(finalText)
        }
    }
}

// MARK: - Carbon Hotkey Callback (C function)

private func carbonHotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }

    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

    DispatchQueue.main.async {
        delegate.toggleRecording()
    }

    return noErr
}
