import AppKit

// The practice surface. Characters come from the text system (insertText), so whatever the
// keyboard produces after layers, one-shots and mod-taps is what gets judged.
final class TypingView: NSView {
    struct Result { let wpm: Double; let accuracy: Double; let missed: [Character] }

    var onProgress: ((_ typed: Int, _ total: Int, _ wpm: Double, _ accuracy: Double) -> Void)?
    var onNextChar: ((Character?) -> Void)?
    var onFinish: ((Result) -> Void)?
    var onRequestNext: (() -> Void)?
    var onWrong: ((Character) -> Void)?
    var stats: Stats?

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

    private let font = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
    private lazy var cw: CGFloat = ("M" as NSString).size(withAttributes: [.font: font]).width
    private let lh: CGFloat = 30

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

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
        invalidateIntrinsicContentSize()
        needsDisplay = true
        report()
    }

    var codeSize: NSSize {
        let cols = lineStarts.enumerated().map { n, s in (n + 1 < lineStarts.count ? lineStarts[n + 1] - 1 : text.count) - s }.max() ?? 0
        return NSSize(width: CGFloat(cols + 2) * cw, height: CGFloat(lineStarts.count) * lh)
    }

    // MARK: input
    override func keyDown(with event: NSEvent) { interpretKeyEvents([event]) }
    override func insertText(_ insertString: Any) {
        let s = (insertString as? String) ?? (insertString as? NSAttributedString)?.string ?? ""
        for ch in s { type(ch) }
    }
    override func insertNewline(_ sender: Any?) { finished ? onRequestNext?() : type("\n") }
    override func insertTab(_ sender: Any?) {}
    override func deleteBackward(_ sender: Any?) {}      // no need to correct: just type the right key
    override func cancelOperation(_ sender: Any?) { onRequestNext?() }
    override func doCommand(by selector: Selector) { if responds(to: selector) { perform(selector, with: nil) } }

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in self?.flash = false; self?.needsDisplay = true }
        }
        needsDisplay = true
        report()
    }

    private func skipIndent() {
        // like an editor's auto-indent: leading spaces on a new line are typed for you
        while pos < text.count && text[pos] == " " && (pos == 0 || text[pos - 1] == "\n" || (pos > 0 && text[pos - 1] == " " && lineStart(pos))) { pos += 1 }
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
        needsDisplay = true
        report()
    }

    // MARK: drawing
    override func draw(_ dirtyRect: NSRect) {
        let origin = NSPoint(x: max(0, (bounds.width - codeSize.width) / 2), y: max(0, (bounds.height - codeSize.height) / 2))
        for (n, s) in lineStarts.enumerated() {
            let end = n + 1 < lineStarts.count ? lineStarts[n + 1] - 1 : text.count
            let y = origin.y + CGFloat(n) * lh
            for i in s...max(s, end) where i <= text.count {
                let x = origin.x + CGFloat(i - s) * cw
                let isNewline = i == end
                if isNewline && (i >= text.count || i != pos) { continue }
                let ch: String = isNewline ? "↵" : String(text[i])
                let r = NSRect(x: x, y: y + 2, width: cw, height: lh - 4)
                if i == pos && !finished {
                    (flash ? NSColor.systemRed : NSColor.labelColor).withAlphaComponent(flash ? 0.85 : 0.85).setFill()
                    NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3).fill()
                }
                var color = isNewline ? NSColor.secondaryLabelColor : Syntax.color(kinds[min(i, kinds.count - 1)])
                if i < pos { color = errorAt.contains(i) ? NSColor.systemRed : color.withAlphaComponent(0.32) }
                if i == pos && !finished { color = NSColor.textBackgroundColor }
                (ch as NSString).draw(at: NSPoint(x: x, y: y + (lh - font.boundingRectForFont.height) / 2 + 2),
                                      withAttributes: [.font: font, .foregroundColor: color])
                if i < pos && errorAt.contains(i) {
                    NSColor.systemRed.setFill()
                    NSRect(x: x, y: y + lh - 4, width: cw, height: 2).fill()
                }
            }
        }
    }
}

extension Syntax {
    static func color(_ k: Kind) -> NSColor {
        switch k {
        case .keyword: return .systemPurple
        case .string: return .systemOrange
        case .comment: return .secondaryLabelColor
        case .number: return .systemBlue
        case .type: return .systemTeal
        case .punct: return .labelColor
        case .plain: return .labelColor
        }
    }
}
