import UIKit

// What the keyboard is doing, pieced together from the F13-F22 signal keys the firmware taps
// (keymap.c, "State reporting") plus the modifier keys iPadOS reports directly.
struct KeyState: Equatable {
    var layer = 0
    var oneShot: UInt8 = 0      // QMK mod bits: 0x01 Ctrl, 0x02 Shift, 0x04 Alt, 0x08 Cmd
    var held: UInt8 = 0
    var caps = false
    var signalled = false       // a signal key has arrived since launch

    static let signalKeys: ClosedRange<Int> = UIKeyboardHIDUsage.keyboardF13.rawValue...UIKeyboardHIDUsage.keyboardF22.rawValue

    // returns true when the press was a signal key
    mutating func apply(_ code: UIKeyboardHIDUsage) -> Bool {
        let r = code.rawValue
        guard KeyState.signalKeys.contains(r) else { return false }
        signalled = true
        switch r - UIKeyboardHIDUsage.keyboardF13.rawValue {
        case 0...4: layer = r - UIKeyboardHIDUsage.keyboardF13.rawValue
        case 5: oneShot = 0
        case 6: oneShot |= 0x08
        case 7: oneShot |= 0x04
        case 8: oneShot |= 0x01
        case 9: oneShot |= 0x02
        default: break
        }
        return true
    }

    static func modBit(_ code: UIKeyboardHIDUsage) -> UInt8? {
        switch code {
        case .keyboardLeftControl, .keyboardRightControl: return 0x01
        case .keyboardLeftShift, .keyboardRightShift: return 0x02
        case .keyboardLeftAlt, .keyboardRightAlt: return 0x04
        case .keyboardLeftGUI, .keyboardRightGUI: return 0x08
        default: return nil
        }
    }
}

// Which keys to press for a character: the key itself, plus the SYM thumb and/or a Shift pinky.
enum Target {
    private static let base = Array("qwertyuiopasdfghjkl;zxcvbnm,./")
    private static let sym = Array("1234567890!@#$%^&*()`~\\|-=+[]'")
    private static let shifted: [Character: Character] = ["?": "/", ":": ";", "<": ",", ">": ".", "_": "-", "{": "[", "}": "]", "\"": "'"]

    private static func shift(for i: Int) -> Int { i % 10 >= 5 ? 20 : 29 }   // opposite hand's pinky

    static func keys(for ch: Character) -> [Int] {
        if ch == " " { return [32] }
        if ch == "\n" { return [33] }
        if ch.isLetter, let i = base.firstIndex(of: Character(ch.lowercased())) {
            return ch.isUppercase ? [i, shift(for: i)] : [i]
        }
        if let i = base.firstIndex(of: ch) { return [i] }
        if let i = sym.firstIndex(of: ch) { return [i, 31] }
        if let b = shifted[ch] {
            if let i = sym.firstIndex(of: b) { return [i, 31, shift(for: i)] }
            if let i = base.firstIndex(of: b) { return [i, shift(for: i)] }
        }
        return []
    }
}
