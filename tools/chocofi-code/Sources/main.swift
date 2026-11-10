import AppKit

// Chocofi Code: a TypeScript typing trainer for the Chocofi.
final class Trainer: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private let typing = TypingView()
    private let stats = Stats()
    private let modes = NSSegmentedControl()
    private let title = NSTextField(labelWithString: "")
    private let progress = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "")
    private let result = NSTextField(labelWithString: "")
    private let folderButton = NSButton(title: "Choose Folder…", target: nil, action: nil)
    private let hintsAlways = NSButton(checkboxWithTitle: "Always show hints", target: nil, action: nil)
    private var folderSnippets: [Snippet] = []
    private var hintTimer: Timer?
    private var nextChar: Character?
    private var lastTitle = ""
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ note: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 640),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Chocofi Code"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 760, height: 520)
        window.delegate = self
        window.center()
        buildUI()
        if let path = defaults.string(forKey: "folder") { loadFolder(URL(fileURLWithPath: path)) }
        modes.selectedSegment = Category.allCases.firstIndex { $0.rawValue == defaults.string(forKey: "mode") } ?? 0
        next()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(typing)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.mainMenu = makeMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ note: Notification) { stats.save() }

    private func buildUI() {
        let v = window.contentView!
        modes.segmentCount = Category.allCases.count
        for (i, c) in Category.allCases.enumerated() { modes.setLabel(c.rawValue, forSegment: i); modes.setWidth(0, forSegment: i) }
        modes.target = self; modes.action = #selector(modeChanged)
        folderButton.target = self; folderButton.action = #selector(chooseFolder)
        folderButton.bezelStyle = .rounded
        hintsAlways.target = self; hintsAlways.action = #selector(toggleHints)
        hintsAlways.state = defaults.bool(forKey: "hintsAlways") ? .on : .off
        title.font = .systemFont(ofSize: 13, weight: .semibold); title.textColor = .secondaryLabelColor
        progress.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular); progress.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 15, weight: .medium); hint.textColor = .controlAccentColor
        result.font = .systemFont(ofSize: 16, weight: .semibold); result.alignment = .center
        result.lineBreakMode = .byWordWrapping; result.maximumNumberOfLines = 3

        typing.stats = stats
        typing.onProgress = { [weak self] t, total, wpm, acc in
            self?.progress.stringValue = "\(t) chars · \(wpm > 0 ? String(Int(wpm.rounded())) : "–") wpm · \(Int((acc * 100).rounded()))% accuracy"
        }
        typing.onNextChar = { [weak self] c in self?.nextChar = c; self?.armHint(reveal: false) }
        typing.onWrong = { [weak self] _ in self?.armHint(reveal: true) }
        typing.onFinish = { [weak self] r in self?.showResult(r) }
        typing.onRequestNext = { [weak self] in self?.next() }

        let top = NSStackView(views: [modes, folderButton, NSView(), hintsAlways])
        top.orientation = .horizontal; top.spacing = 12
        let bottom = NSStackView(views: [hint, NSView(), progress])
        bottom.orientation = .horizontal
        for x in [top, title, typing, result, bottom] as [NSView] { x.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(x) }
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: v.topAnchor, constant: 40),
            top.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 24),
            top.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -24),
            title.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 24),
            typing.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            typing.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 24),
            typing.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -24),
            typing.bottomAnchor.constraint(equalTo: result.topAnchor, constant: -8),
            result.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 24),
            result.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -24),
            result.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -12),
            bottom.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 24),
            bottom.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -24),
            bottom.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -20),
        ])
    }

    private var mode: Category { Category.allCases[max(0, modes.selectedSegment)] }

    private func pool() -> [Snippet] {
        switch mode {
        case .folder:
            return folderSnippets
        case .weak:
            // snippets dense in the symbols you miss or type slowest
            let weak = Set(stats.weakSymbols())
            guard !weak.isEmpty else { return Snippets.all }
            let scored = Snippets.all.map { s -> (Snippet, Double) in
                let hits = s.code.filter { weak.contains($0) }.count
                return (s, Double(hits) / Double(max(1, s.code.count)))
            }.sorted { $0.1 > $1.1 }
            return Array(scored.prefix(8).map { $0.0 })
        default:
            return Snippets.all.filter { $0.category == mode }
        }
    }

    private func next() {
        folderButton.isHidden = mode != .folder
        var p = pool()
        if p.count > 1 { p.removeAll { $0.title == lastTitle && $0.category == mode } }
        result.stringValue = ""
        guard let s = p.randomElement() else {
            title.stringValue = mode == .folder ? "Choose a folder with .ts or .tsx files to practise on your own code." : "Nothing to practise here yet."
            typing.load("")
            return
        }
        lastTitle = s.title
        var heading = s.title.uppercased()
        if mode == .weak { heading += "  ·  weak: " + stats.weakSymbols().map(String.init).joined(separator: " ") }
        title.stringValue = heading
        typing.load(s.code)
        window.makeFirstResponder(typing)
    }

    private func showResult(_ r: TypingView.Result) {
        hint.stringValue = ""
        let missed = r.missed.isEmpty ? "No misses." : "Missed: " + r.missed.map { $0 == "\n" ? "↵" : String($0) }.joined(separator: "  ")
        result.stringValue = "\(Int(r.wpm.rounded())) wpm  ·  \(Int((r.accuracy * 100).rounded()))% accuracy  ·  \(missed)\nPress Enter for the next snippet."
    }

    // hint: always, after a 1.5 s pause, or straight away after a miss
    private func armHint(reveal: Bool) {
        hintTimer?.invalidate()
        let text = nextChar.flatMap { Hints.hint(for: $0) }.map { "Next \(nextChar == "\n" ? "↵" : String(nextChar!)): \($0)" } ?? ""
        if reveal || hintsAlways.state == .on { hint.stringValue = text; return }
        hint.stringValue = ""
        guard !text.isEmpty else { return }
        hintTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in self?.hint.stringValue = text }
    }

    @objc private func modeChanged() { defaults.set(mode.rawValue, forKey: "mode"); next() }
    @objc private func toggleHints() { defaults.set(hintsAlways.state == .on, forKey: "hintsAlways"); armHint(reveal: false); window.makeFirstResponder(typing) }
    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.prompt = "Practise This Folder"
        if panel.runModal() == .OK, let url = panel.url {
            defaults.set(url.path, forKey: "folder")
            loadFolder(url)
            next()
        }
        window.makeFirstResponder(typing)
    }
    private func loadFolder(_ url: URL) { folderSnippets = FolderSource.snippets(in: url) }
    @objc private func resetStats() { stats.reset(); next() }
    @objc private func skip() { next() }

    private func makeMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Clear Typing Stats", action: #selector(resetStats), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Chocofi Code", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let practiceItem = NSMenuItem(); main.addItem(practiceItem)
        let practice = NSMenu(title: "Practice")
        practice.addItem(withTitle: "Next Snippet", action: #selector(skip), keyEquivalent: "n").target = self
        practice.addItem(withTitle: "Choose Folder…", action: #selector(chooseFolder), keyEquivalent: "o").target = self
        practiceItem.submenu = practice
        return main
    }
}

let app = NSApplication.shared
let trainer = Trainer()
app.delegate = trainer
app.setActivationPolicy(.regular)
app.run()
