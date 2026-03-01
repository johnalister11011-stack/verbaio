import Foundation
import Carbon.HIToolbox

@Observable
final class HotkeySettings {
    var keyCode: Int64 {
        didSet { save() }
    }
    var modifierFlags: CGEventFlags {
        didSet { save() }
    }
    var isListeningForNewHotkey = false

    private static let keyCodeKey = "hotkeyKeyCode"
    private static let modifierFlagsKey = "hotkeyModifierFlags"

    // Default: ] key (keyCode 30), no modifiers
    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.keyCodeKey) != nil {
            self.keyCode = Int64(defaults.integer(forKey: Self.keyCodeKey))
            self.modifierFlags = CGEventFlags(rawValue: UInt64(defaults.integer(forKey: Self.modifierFlagsKey)))
        } else {
            self.keyCode = 30 // ] key
            self.modifierFlags = CGEventFlags(rawValue: 0)
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: Self.keyCodeKey)
        defaults.set(Int(modifierFlags.rawValue), forKey: Self.modifierFlagsKey)
    }

    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard self.keyCode == keyCode else { return false }

        let relevantMask: UInt64 = CGEventFlags.maskCommand.rawValue
            | CGEventFlags.maskShift.rawValue
            | CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskControl.rawValue

        let requiredMods = self.modifierFlags.rawValue & relevantMask
        let eventMods = flags.rawValue & relevantMask

        return requiredMods == eventMods
    }

    var displayString: String {
        var parts: [String] = []

        if modifierFlags.contains(.maskControl) { parts.append("⌃") }
        if modifierFlags.contains(.maskAlternate) { parts.append("⌥") }
        if modifierFlags.contains(.maskShift) { parts.append("⇧") }
        if modifierFlags.contains(.maskCommand) { parts.append("⌘") }

        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    func keyName(for code: Int64) -> String {
        let names: [Int64: String] = [
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
