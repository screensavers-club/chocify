import UIKit
import UniformTypeIdentifiers

// Chocofi Code for iPad: the TypeScript typing trainer, with the layer map docked underneath.
final class TrainerViewController: UIViewController, UIDocumentPickerDelegate {
    let stats = Stats()
    private let typing = TypingView()
    private let board = BoardView()
    private let modes = UISegmentedControl(items: Category.allCases.map(\.rawValue))
    private let titleLabel = UILabel()
    private let progress = UILabel()
    private let hint = UILabel()
    private let result = UILabel()
    private let folderButton = UIButton(configuration: .gray())
    private let hintsSwitch = UISwitch()
    private let mapSwitch = UISwitch()
    private var folderSnippets: [Snippet] = []
    private var hintTimer: Timer?
    private var nextChar: Character?
    private var lastTitle = ""
    private let defaults = UserDefaults.standard

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildUI()
        restoreFolder()
        let saved = Category.allCases.firstIndex { $0.rawValue == defaults.string(forKey: "mode") } ?? 0
        modes.selectedSegmentIndex = saved
        next()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        typing.becomeFirstResponder()
    }

    private func label(_ text: String) -> UILabel {
        let l = UILabel(); l.text = text; l.font = .systemFont(ofSize: 13); l.textColor = .secondaryLabel; return l
    }

    private func buildUI() {
        modes.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modes.apportionsSegmentWidthsByContent = true
        folderButton.configuration?.title = "Choose Folder…"
        folderButton.addTarget(self, action: #selector(chooseFolder), for: .touchUpInside)
        hintsSwitch.isOn = defaults.bool(forKey: "hintsAlways")
        hintsSwitch.addTarget(self, action: #selector(toggleHints), for: .valueChanged)
        mapSwitch.isOn = defaults.object(forKey: "showMap") as? Bool ?? true
        mapSwitch.addTarget(self, action: #selector(toggleMap), for: .valueChanged)
        board.isHidden = !mapSwitch.isOn

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold); titleLabel.textColor = .secondaryLabel
        progress.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular); progress.textColor = .secondaryLabel
        progress.setContentHuggingPriority(.required, for: .horizontal)
        hint.font = .systemFont(ofSize: 15, weight: .medium); hint.textColor = .tintColor
        hint.adjustsFontSizeToFitWidth = true; hint.minimumScaleFactor = 0.7
        result.font = .systemFont(ofSize: 16, weight: .semibold); result.textAlignment = .center; result.numberOfLines = 3

        typing.stats = stats
        typing.onProgress = { [weak self] t, _, wpm, acc in
            self?.progress.text = "\(t) chars · \(wpm > 0 ? String(Int(wpm.rounded())) : "–") wpm · \(Int((acc * 100).rounded()))% accuracy"
        }
        typing.onNextChar = { [weak self] c in
            self?.nextChar = c
            self?.board.target = c.map(Target.keys(for:)) ?? []
            self?.armHint(reveal: false)
        }
        typing.onWrong = { [weak self] _ in self?.armHint(reveal: true) }
        typing.onFinish = { [weak self] r in self?.showResult(r) }
        typing.onRequestNext = { [weak self] in self?.next() }
        typing.onKeyState = { [weak self] s in self?.board.state = s }

        let toggles = UIStackView(arrangedSubviews: [label("Hints"), hintsSwitch, label("Map"), mapSwitch])
        toggles.spacing = 8; toggles.alignment = .center
        let top = UIStackView(arrangedSubviews: [modes, folderButton, UIView(), toggles])
        top.spacing = 12; top.alignment = .center
        let bottom = UIStackView(arrangedSubviews: [hint, progress])
        bottom.spacing = 12
        let column = UIStackView(arrangedSubviews: [top, titleLabel, typing, result, bottom, board])
        column.axis = .vertical; column.spacing = 10
        column.setCustomSpacing(18, after: top)
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: g.topAnchor, constant: 16),
            column.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24),
            column.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -24),
            column.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
            board.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3),
        ])
        typing.setContentHuggingPriority(.defaultLow, for: .vertical)
        typing.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    private var mode: Category { Category.allCases[max(0, modes.selectedSegmentIndex)] }

    private func pool() -> [Snippet] {
        switch mode {
        case .folder:
            return folderSnippets
        case .weak:
            let weak = Set(stats.weakSymbols())
            guard !weak.isEmpty else { return Snippets.all }
            let scored = Snippets.all.map { s -> (Snippet, Double) in
                (s, Double(s.code.filter { weak.contains($0) }.count) / Double(max(1, s.code.count)))
            }.sorted { $0.1 > $1.1 }
            return Array(scored.prefix(8).map { $0.0 })
        default:
            return Snippets.all.filter { $0.category == mode }
        }
    }

    private func next() {
        folderButton.isHidden = mode != .folder
        var p = pool()
        if p.count > 1 { p.removeAll { $0.title == lastTitle } }
        result.text = ""
        guard let s = p.randomElement() else {
            titleLabel.text = mode == .folder ? "Choose a folder (Files app) with .ts or .tsx files to practise on your own code." : "Nothing to practise here yet."
            typing.load("")
            return
        }
        lastTitle = s.title
        var heading = s.title.uppercased()
        if mode == .weak { heading += "  ·  weak: " + stats.weakSymbols().map(String.init).joined(separator: " ") }
        titleLabel.text = heading
        typing.load(s.code)
        typing.becomeFirstResponder()
    }

    private func showResult(_ r: TypingView.Result) {
        hint.text = ""
        let missed = r.missed.isEmpty ? "No misses." : "Missed: " + r.missed.map { $0 == "\n" ? "↵" : String($0) }.joined(separator: "  ")
        result.text = "\(Int(r.wpm.rounded())) wpm  ·  \(Int((r.accuracy * 100).rounded()))% accuracy  ·  \(missed)\nPress Enter for the next snippet."
    }

    // hint: always, after a 1.5 s pause, or straight away after a miss
    private func armHint(reveal: Bool) {
        hintTimer?.invalidate()
        let text = nextChar.flatMap { Hints.hint(for: $0) }.map { "Next \(nextChar == "\n" ? "↵" : String(nextChar!)): \($0)" } ?? ""
        if reveal || hintsSwitch.isOn { hint.text = text; return }
        hint.text = ""
        guard !text.isEmpty else { return }
        hintTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in self?.hint.text = text }
    }

    @objc private func modeChanged() { defaults.set(mode.rawValue, forKey: "mode"); next() }
    @objc private func toggleHints() { defaults.set(hintsSwitch.isOn, forKey: "hintsAlways"); armHint(reveal: false); typing.becomeFirstResponder() }
    @objc private func toggleMap() {
        defaults.set(mapSwitch.isOn, forKey: "showMap")
        UIView.animate(withDuration: 0.2) { self.board.isHidden = !self.mapSwitch.isOn }
        typing.becomeFirstResponder()
    }
    @objc private func skip() { next() }
    @objc private func resetStats() { stats.reset(); next() }

    // MARK: folder of your own code (via the Files app)
    @objc private func chooseFolder() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = self
        present(picker, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if let data = try? url.bookmarkData() { defaults.set(data, forKey: "folderBookmark") }
        loadFolder(url)
        next()
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { typing.becomeFirstResponder() }

    private func restoreFolder() {
        guard let data = defaults.data(forKey: "folderBookmark") else { return }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) { loadFolder(url) }
    }
    private func loadFolder(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()   // kept open while the app runs
        folderSnippets = FolderSource.snippets(in: url)
    }

    // MARK: hardware keyboard shortcuts
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(title: "Next Snippet", action: #selector(skip), input: "n", modifierFlags: .command),
         UIKeyCommand(title: "Choose Folder…", action: #selector(chooseFolder), input: "o", modifierFlags: .command),
         UIKeyCommand(title: "Clear Typing Stats", action: #selector(resetStats), input: "k", modifierFlags: [.command, .shift])]
    }
}
