import CoreGraphics

// Mirror of firmware/qmk/handwired/chocofi_hw/keymaps/default/keymap.c (labels only).
// Positions 0-29: three rows of ten across both halves; 30-35: thumbs, left to right.
// An empty string is unused; "·" is transparent (falls through to BASE).
enum Keymap {
    static let layerNames = ["BASE", "SYM", "NAV", "ADJUST", "MOUSE"]

    static let layers: [[String]] = [
        // BASE
        ["Q","W","E","R","T","Y","U","I","O","P",
         "A","S","D","F","G","H","J","K","L",";",
         "Z","X","C","V","B","N","M",",",".","/",
         "⌘","SYM","Space","Enter","NAV","⌫"],
        // SYM
        ["1","2","3","4","5","6","7","8","9","0",
         "!","@","#","$","%","^","&","*","(",")",
         "`","~","\\","|","-","=","+","[","]","'",
         "·","·","·","·","·","Del"],
        // NAV (A S D F are one-shot modifiers)
        ["Esc","Tab","Caps","","","PgUp","Home","↑","End","Del",
         "⌘","⌥","⌃","⇧","","PgDn","←","↓","→","⌫",
         "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10",
         "·","·","·","·","·","·"],
        // ADJUST (SYM + NAV)
        ["Boot","","","","","","","iPad","","Boot",
         "F11","F12","","","","Prev","Vol−","Vol+","Next","Play",
         "","","","","","","Mute","","","",
         "·","·","·","·","·","·"],
        // MOUSE (hold ⌫)
        ["","","","","","Scr↑","Scr←","↑","Scr→","",
         "Slow","Mid","Right","Left","","Scr↓","←","↓","→","",
         "⇧","⌥","⌃","","","","","","","",
         "·","Right","Left","","","·"],
    ]

    // the key held to reach each layer, highlighted on the map
    static let layerKey: [Int: [Int]] = [1: [31], 2: [34], 3: [31, 34], 4: [35]]

    static let geo: [(CGFloat, CGFloat)] = [
        (0,0.6),(1,0.3),(2,0),(3,0.4),(4,0.5),(8,0.5),(9,0.4),(10,0),(11,0.3),(12,0.6),
        (0,1.6),(1,1.3),(2,1),(3,1.4),(4,1.5),(8,1.5),(9,1.4),(10,1),(11,1.3),(12,1.6),
        (0,2.6),(1,2.3),(2,2),(3,2.4),(4,2.5),(8,2.5),(9,2.4),(10,2),(11,2.3),(12,2.6),
        (2.5,3.6),(3.5,3.8),(4.6,4.1),(7.4,4.1),(8.5,3.8),(9.5,3.6),
    ]
    static let rotation: [Int: CGFloat] = [31: 5, 32: 13, 33: -13, 34: -5]
    static func isRight(_ i: Int) -> Bool { i < 30 ? i % 10 >= 5 : i >= 33 }

    static func label(layer: Int, index i: Int) -> String {
        let l = layers[layer][i]
        return l == "·" ? layers[0][i] : l
    }
}
