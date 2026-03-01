import AppKit
import Carbon.HIToolbox

@Observable
final class HotkeySettings {
    var keyCode: UInt32 {
        didSet { save() }
    }
    var carbonModifiers: UInt32 {
        didSet { save() }
    }
    var isListeningForNewHotkey = false

    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifierFlagsKey = "hotkeyModifierFlags"

    // Default: Cmd+Shift+Space
    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.keyCodeKey) != nil {
            self.keyCode = UInt32(defaults.integer(forKey: Self.keyCodeKey))
            self.carbonModifiers = UInt32(defaults.integer(forKey: Self.modifierFlagsKey))
        } else {
            self.keyCode = UInt32(kVK_Space)          // 49
            self.carbonModifiers = UInt32(cmdKey | shiftKey)
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: Self.keyCodeKey)
        defaults.set(Int(carbonModifiers), forKey: Self.modifierFlagsKey)
    }

    var displayString: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    // Convert NSEvent modifier flags to Carbon modifiers
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    func keyName(for code: UInt32) -> String {
        let names: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "Tab", 49: "Space", 50: "`", 51: "Delete",
            53: "Escape",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15",
            115: "Home", 116: "PageUp", 117: "FwdDel",
            118: "F4", 119: "End", 120: "F2", 121: "PageDown", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return names[code] ?? "Key(\(code))"
    }
}
