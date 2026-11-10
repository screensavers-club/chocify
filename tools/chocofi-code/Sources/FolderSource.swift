import Foundation

// Pulls practice blocks out of your own .ts/.tsx files: 3-14 line chunks that start at a
// top-level declaration, with tabs turned into two spaces and very long lines skipped.
enum FolderSource {
    static let skipDirs: Set<String> = ["node_modules", ".git", "dist", "build", ".next", "coverage", "out", ".turbo", "vendor"]

    static func snippets(in root: URL, maxFiles: Int = 400) -> [Snippet] {
        var files: [URL] = []
        let fm = FileManager.default
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        for case let url as URL in e {
            if skipDirs.contains(url.lastPathComponent) { e.skipDescendants(); continue }
            let ext = url.pathExtension
            if (ext == "ts" || ext == "tsx") && !url.lastPathComponent.hasSuffix(".d.ts") { files.append(url) }
            if files.count >= maxFiles { break }
        }
        var out: [Snippet] = []
        let starts = ["export ", "function ", "const ", "let ", "interface ", "type ", "class ", "async ", "enum "]
        for f in files {
            guard let text = try? String(contentsOf: f, encoding: .utf8) else { continue }
            let lines = text.replacingOccurrences(of: "\t", with: "  ").components(separatedBy: .newlines)
            var i = 0
            while i < lines.count {
                let line = lines[i]
                guard starts.contains(where: { line.hasPrefix($0) }) else { i += 1; continue }
                var j = i
                var block: [String] = []
                while j < lines.count && block.count < 14 {
                    let l = lines[j]
                    if j > i && (l.isEmpty || starts.contains(where: { l.hasPrefix($0) })) { break }
                    block.append(l)
                    j += 1
                }
                while let last = block.last, last.trimmingCharacters(in: .whitespaces).isEmpty { block.removeLast() }
                let ok = block.count >= 3 && block.allSatisfy { $0.count <= 90 && $0.unicodeScalars.allSatisfy { $0.isASCII } }
                if ok {
                    out.append(Snippet(title: f.lastPathComponent, category: .folder,
                                       code: block.map { String($0.reversed().drop(while: { $0 == " " }).reversed()) }.joined(separator: "\n")))
                }
                i = max(j, i + 1)
            }
        }
        return out
    }
}
