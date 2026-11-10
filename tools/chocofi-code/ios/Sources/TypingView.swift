import UIKit

// The practice surface. Characters arrive through UIKeyInput.insertText, so whatever the
// keyboard produces after layers, one-shots and mod-taps is what gets judged. Signal keys
// (F13-F22) and modifier keys are read from the raw presses.
final class TypingView: UIView, UIKeyInput {
    struct Result { let wpm: Double; let accuracy: Double; let missed: [Character] }

    var onProgress: ((_ typed: Int, _ total: Int, _ wpm: Double, _ accuracy: Double) -> Void)?
    var onNextChar: ((Character?) -> Void)?
    var onFinish: ((Result) -> Void)?
    var onRequestNext: (() -> Void)?
    var onWrong: ((Character) -> Void)?
    var onKeyState: ((KeyState) -> Void)?
    var stats: Stats?
    private(set) var keyState = KeyState() { didSet { if keyState != oldValue { onKeyState?(keyState) } } }

    private var text: [Character] = []
    private var lineStarts: [Int] = []
    private var kinds: [Syntax.Kind] = []
    private(set) var pos = 0
    private var errorAt = Set<Int>()
    private var correct = 0, wrong = 0, typedChars = 0
    private var start: Date?, last: Date?
    private var flash = false
    private(set) var finished = false
    private var missed: [Character: Int] = [:]

    // UITextInputTraits: no autocorrect, capitals, smart punctuation
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var keyboardType: UIKeyboardType = .asciiCapable
    var inlinePredictionType: UITextInlinePredictionType = .no

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus)))
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func focus() { becomeFirstResponder() }

    override var canBecomeFirstResponder: Bool { true }

    func load(_ code: String) {
        text = Array(code.replacingOccurrences(of: "\r\n", with: "\n"))
        lineStarts = [0] + text.indices.filter { text[$0] == "\n" }.map { $0 + 1 }
        kinds = []
        for (n, s) in lineStarts.enumerated() {
            let end = n + 1 < lineStarts.count ? lineStarts[n + 1] - 1 : text.count
            kinds += Syntax.kinds(of: Array(text[s..<end]))
            if end < text.count { kinds.append(.plain) }
        }
        pos = 0; errorAt = []; correct = 0; wrong = 0; typedChars = 0; start = nil; last = nil; finished = false; missed = [:]
        skipIndent()
        setNeedsDisplay()
        report()
    }

    // MARK: input
    var hasText: Bool { true }
    func insertText(_ s: String) {
        for ch in s {
            if ch == "\n" || ch == "\r" { finished ? onRequestNext?() : type("\n") }
            else if ch == "\t" { continue }
            else { type(ch) }
        }
    }
    func deleteBackward() {}   // no need to correct: just type the right key

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var rest = Set<UIPress>()
        for p in presses {
            guard let key = p.key else { rest.insert(p); continue }
            if keyState.apply(key.keyCode) { continue }
            if let bit = KeyState.modBit(key.keyCode) { keyState.held |= bit }
            if key.keyCode == .keyboardEscape { onRequestNext?(); continue }
            keyState.caps = key.modifierFlags.contains(.alphaShift)
            rest.insert(p)
        }
        if !rest.isEmpty { super.pressesBegan(rest, with: event) }
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var rest = Set<UIPress>()
        for p in presses {
            guard let key = p.key else { rest.insert(p); continue }
            if KeyState.signalKeys.contains(key.keyCode.rawValue) || key.keyCode == .keyboardEscape { continue }
            if let bit = KeyState.modBit(key.keyCode) { keyState.held &= ~bit }
            keyState.caps = key.modifierFlags.contains(.alphaShift)
            rest.insert(p)
        }
        if !rest.isEmpty { super.pressesEnded(rest, with: event) }
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        keyState.held = 0
        super.pressesCancelled(presses, with: event)
    }

    private func type(_ ch: Character) {
        guard !finished, pos < text.count else { return }
        let now = Date()
        if start == nil { start = now }
        let expected = text[pos]
        if ch == expected {
            stats?.hit(expected, ms: last.map { now.timeIntervalSince($0) * 1000 })
            correct += 1; typedChars += 1; pos += 1; last = now
            skipIndent()
            if pos >= text.count { finish(); return }
        } else {
            wrong += 1; errorAt.insert(pos)
            missed[expected, default: 0] += 1
            stats?.miss(expected)
            onWrong?(expected)
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in self?.flash = false; self?.setNeedsDisplay() }
        }
        setNeedsDisplay()
        report()
    }

    private func skipIndent() {
        // like an editor's auto-indent: leading spaces on a new line are typed for you
        while pos < text.count && text[pos] == " " && lineStart(pos) { pos += 1 }
    }
    private func lineStart(_ p: Int) -> Bool {
        var i = p - 1
        while i >= 0 && text[i] == " " { i -= 1 }
        return i < 0 || text[i] == "\n"
    }

    private var wpm: Double {
        guard let s = start, let l = last, l > s else { return 0 }
        return Double(typedChars) / 5 / (l.timeIntervalSince(s) / 60)
    }
    private var accuracy: Double { correct + wrong == 0 ? 1 : Double(correct) / Double(correct + wrong) }

    private func report() {
        onProgress?(typedChars, text.count, typedChars > 4 ? wpm : 0, accuracy)
        onNextChar?(finished ? nil : (pos < text.count ? text[pos] : nil))
    }

    private func finish() {
        finished = true
        stats?.save()
        let top = missed.sorted { $0.value > $1.value }.prefix(6).map { $0.key }
        onFinish?(Result(wpm: wpm, accuracy: accuracy, missed: top))
        setNeedsDisplay()
        report()
    }

    // MARK: drawing
    override func layoutSubviews() { super.layoutSubviews(); setNeedsDisplay() }

    override func draw(_ rect: CGRect) {
        let cols = lineStarts.enumerated().map { n, s in (n + 1 < lineStarts.count ? lineStarts[n + 1] - 1 : text.count) - s }.max() ?? 0
        // fit the longest line and all rows: 18 pt where there's room, smaller in portrait
        let probe = UIFont.monospacedSystemFont(ofSize: 100, weight: .regular)
        let ratio = ("M" as NSString).size(withAttributes: [.font: probe]).width / 100
        let byWidth = bounds.width / CGFloat(cols + 2) / ratio
        let byHeight = bounds.height / CGFloat(max(1, lineStarts.count)) / 1.65
        let size = max(10, min(20, byWidth, byHeight))
        let font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let cw = ratio * size, lh = size * 1.65
        let w = CGFloat(cols + 1) * cw, h = CGFloat(lineStarts.count) * lh
        let origin = CGPoint(x: max(0, (bounds.width - w) / 2), y: max(0, (bounds.height - h) / 2))

        for (n, s) in lineStarts.enumerated() {
            let end = n + 1 < lineStarts.count ? lineStarts[n + 1] - 1 : text.count
            let y = origin.y + CGFloat(n) * lh
            for i in s...max(s, end) where i <= text.count {
                let x = origin.x + CGFloat(i - s) * cw
                let isNewline = i == end
                if isNewline && (i >= text.count || i != pos) { continue }
                let ch: String = isNewline ? "↵" : String(text[i])
                let r = CGRect(x: x, y: y + 2, width: cw, height: lh - 4)
                if i == pos && !finished {
                    (flash ? UIColor.systemRed : UIColor.label).withAlphaComponent(0.85).setFill()
                    UIBezierPath(roundedRect: r, cornerRadius: 3).fill()
                }
                var color = isNewline ? UIColor.secondaryLabel : Syntax.color(kinds[min(i, kinds.count - 1)])
                if i < pos { color = errorAt.contains(i) ? .systemRed : color.withAlphaComponent(0.32) }
                if i == pos && !finished { color = .systemBackground }
                (ch as NSString).draw(at: CGPoint(x: x, y: y + (lh - font.lineHeight) / 2),
                                      withAttributes: [.font: font, .foregroundColor: color])
                if i < pos && errorAt.contains(i) {
                    UIColor.systemRed.setFill()
                    UIRectFill(CGRect(x: x, y: y + lh - 4, width: cw, height: 2))
                }
            }
        }
    }
}

extension Syntax {
    static func color(_ k: Kind) -> UIColor {
        switch k {
        case .keyword: return .systemPurple
        case .string: return .systemOrange
        case .comment: return .secondaryLabel
        case .number: return .systemBlue
        case .type: return .systemTeal
        case .punct, .plain: return .label
        }
    }
}
