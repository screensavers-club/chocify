import Foundation

// Per-character hits, misses and time, kept between sessions in UserDefaults.
final class Stats {
    struct Entry: Codable { var hits = 0; var misses = 0; var ms = 0.0; var timed = 0 }
    private(set) var entries: [String: Entry] = [:]
    private let key = "charStats"

    init() {
        if let d = UserDefaults.standard.data(forKey: key), let e = try? JSONDecoder().decode([String: Entry].self, from: d) { entries = e }
    }
    func hit(_ c: Character, ms: Double?) {
        var e = entries[String(c)] ?? Entry()
        e.hits += 1
        if let ms, ms < 3000 { e.ms += ms; e.timed += 1 }
        entries[String(c)] = e
    }
    func miss(_ c: Character) { entries[String(c), default: Entry()].misses += 1 }
    func save() { if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d, forKey: key) } }
    func reset() { entries = [:]; save() }

    // Symbols ranked by miss rate plus slowness, once they've been typed a few times
    func weakSymbols(limit: Int = 8) -> [Character] {
        entries.compactMap { k, e -> (Character, Double)? in
            guard let c = k.first, k.count == 1, Hints.isSymbol(c), e.hits + e.misses >= 4 else { return nil }
            let missRate = Double(e.misses) / Double(e.hits + e.misses)
            let avg = e.timed > 0 ? e.ms / Double(e.timed) / 1000 : 0
            return (c, missRate * 3 + avg)
        }.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }
}
