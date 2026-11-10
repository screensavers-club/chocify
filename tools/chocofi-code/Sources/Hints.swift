// How to type a character on the handwired Chocofi (keymap.c). nil = an ordinary letter.
enum Hints {
    private static let base = Array("qwertyuiopasdfghjkl;zxcvbnm,./")
    private static let sym = Array("1234567890!@#$%^&*()`~\\|-=+[]'")
    private static let shifted: [Character: Character] = ["?": "/", ":": ";", "<": ",", ">": ".", "_": "-", "{": "[", "}": "]", "\"": "'"]

    private static func isRight(_ i: Int) -> Bool { i % 10 >= 5 }
    private static func keyName(_ i: Int) -> String { String(base[i]).uppercased() }
    private static func shiftFor(_ i: Int) -> String { isRight(i) ? "Z (left pinky)" : "/ (right pinky)" }

    static func hint(for ch: Character) -> String? {
        switch ch {
        case " ": return nil
        case "\n": return "Enter · right thumb, curved key"
        default: break
        }
        if let i = base.firstIndex(of: Character(ch.lowercased())), ch.isLetter {
            return ch.isUppercase ? "Hold \(shiftFor(i)) · tap \(keyName(i))" : nil
        }
        if let i = sym.firstIndex(of: ch) {
            return "Hold SYM (left thumb, ridged) · tap \(keyName(i))"
        }
        if let b = shifted[ch] {
            if let i = sym.firstIndex(of: b) {
                return "Hold \(shiftFor(i)) · hold SYM · tap \(keyName(i))"
            }
            if let i = base.firstIndex(of: b) {
                return "Hold \(shiftFor(i)) · tap \(b)"
            }
        }
        if let i = base.firstIndex(of: ch) {
            return ch == "/" ? "Tap / quickly (held, it's Shift)" : (i >= 20 ? nil : nil)
        }
        return nil
    }

    // Characters that need a layer or Shift: what the trainer tracks as "symbols"
    static func isSymbol(_ ch: Character) -> Bool { !ch.isLetter && ch != " " && ch != "\n" || ch.isUppercase }
}
