import Foundation

// Small single-line highlighter: keywords, strings, comments, numbers, type names.
enum Syntax {
    static let keywords: Set<String> = [
        "const", "let", "var", "function", "return", "if", "else", "for", "of", "in", "while", "do", "switch",
        "case", "default", "break", "continue", "new", "class", "extends", "implements", "interface", "type",
        "enum", "export", "import", "from", "as", "async", "await", "try", "catch", "finally", "throw", "typeof",
        "keyof", "infer", "is", "satisfies", "readonly", "private", "public", "protected", "static", "this",
        "true", "false", "null", "undefined", "void", "never", "unknown", "any", "number", "string", "boolean",
        "constructor",
    ]

    enum Kind { case plain, keyword, string, comment, number, type, punct }

    static func kinds(of line: [Character]) -> [Kind] {
        var out = [Kind](repeating: .plain, count: line.count)
        var i = 0
        while i < line.count {
            let c = line[i]
            if c == "/" && i + 1 < line.count && line[i + 1] == "/" {
                for j in i..<line.count { out[j] = .comment }
                break
            }
            if c == "\"" || c == "'" || c == "`" {
                var j = i + 1
                while j < line.count && line[j] != c { j += line[j] == "\\" ? 2 : 1 }
                for k in i...min(j, line.count - 1) { out[k] = .string }
                i = j + 1
                continue
            }
            if c.isNumber {
                var j = i
                while j < line.count && (line[j].isNumber || line[j] == "." || line[j] == "_" || line[j].isLetter) { out[j] = .number; j += 1 }
                i = j
                continue
            }
            if c.isLetter || c == "_" || c == "$" || c == "#" {
                var j = i
                while j < line.count && (line[j].isLetter || line[j].isNumber || line[j] == "_" || line[j] == "$" || line[j] == "#") { j += 1 }
                let word = String(line[i..<j])
                let kind: Kind = keywords.contains(word) ? .keyword : (word.first?.isUppercase == true ? .type : .plain)
                for k in i..<j { out[k] = kind }
                i = j
                continue
            }
            if "{}()[]<>=;:,.+-*/%!&|?^~@".contains(c) { out[i] = .punct }
            i += 1
        }
        return out
    }
}
