import Foundation

func escapeStringsValue(_ value: String) -> String {
    var v = value
    v = v.replacingOccurrences(of: "\\", with: "\\\\")
    v = v.replacingOccurrences(of: "\"", with: "\\\"")
    v = v.replacingOccurrences(of: "\n", with: "\\n")
    v = v.replacingOccurrences(of: "\r", with: "\\r")
    v = v.replacingOccurrences(of: "\t", with: "\\t")
    return v
}

func unescapeStringsValue(_ value: String) -> String {
    var v = value
    v = v.replacingOccurrences(of: "\\n", with: "\n")
    v = v.replacingOccurrences(of: "\\r", with: "\r")
    v = v.replacingOccurrences(of: "\\t", with: "\t")
    v = v.replacingOccurrences(of: "\\\"", with: "\"")
    v = v.replacingOccurrences(of: "\\\\", with: "\\")
    return v
}

func parseStringsFile(at url: URL) -> StringsFile {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        return StringsFile(entries: [:])
    }
    // Strict pattern: requires properly escaped quotes per `.strings` format spec.
    let strictPattern = "^\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*;"
    // Lenient fallback: uses greedy match so values containing unescaped ASCII
    // double-quotes (e.g. German typographic „...\" ) can still be recovered.
    let fallbackPattern = "^\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*=\\s*\"(.+)\"\\s*;"
    let strictRegex = try? NSRegularExpression(pattern: strictPattern, options: [])
    let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: [])
    var entries: [String: String] = [:]
    content.enumerateLines { line, _ in
        guard let strictRegex, let fallbackRegex else { return }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        var keyRange: Range<String.Index>? = nil
        var valueRange: Range<String.Index>? = nil
        if let match = strictRegex.firstMatch(in: line, options: [], range: range),
           let kr = Range(match.range(at: 1), in: line),
           let vr = Range(match.range(at: 2), in: line) {
            keyRange = kr
            valueRange = vr
        } else if let match = fallbackRegex.firstMatch(in: line, options: [], range: range),
                  let kr = Range(match.range(at: 1), in: line),
                  let vr = Range(match.range(at: 2), in: line) {
            let key = unescapeStringsValue(String(line[kr]))
            Logger.warn("Lenient parse for key \"\(key)\" in \(url.lastPathComponent) – value may contain unescaped double-quotes.")
            keyRange = kr
            valueRange = vr
        }
        if let kr = keyRange, let vr = valueRange {
            let key = unescapeStringsValue(String(line[kr]))
            let value = unescapeStringsValue(String(line[vr]))
            entries[key] = value
        }
    }
    return StringsFile(entries: entries)
}

/// Parse `.strings` file and return first occurrence line number for each key.
/// Line numbers are 1-based to match GitHub `#L<line>` anchors.
///
/// This parser intentionally mirrors `parseStringsFile` key regex behavior so key
/// extraction remains consistent between value parsing and line lookup.
func parseStringsFileLineNumbers(at url: URL) -> [String: Int] {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        return [:]
    }
    let strictPattern = "^\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*;"
    let fallbackPattern = "^\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*=\\s*\"(.+)\"\\s*;"
    let strictRegex = try? NSRegularExpression(pattern: strictPattern, options: [])
    let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: [])
    var lineNumbers: [String: Int] = [:]
    let lines = content.components(separatedBy: .newlines)
    for (index, line) in lines.enumerated() {
        guard let strictRegex, let fallbackRegex else { continue }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        var keyRange: Range<String.Index>? = nil
        if let match = strictRegex.firstMatch(in: line, options: [], range: range),
           let kr = Range(match.range(at: 1), in: line) {
            keyRange = kr
        } else if let match = fallbackRegex.firstMatch(in: line, options: [], range: range),
                  let kr = Range(match.range(at: 1), in: line) {
            keyRange = kr
        }
        if let kr = keyRange {
            let key = unescapeStringsValue(String(line[kr]))
            if lineNumbers[key] == nil {
                lineNumbers[key] = index + 1
            }
        }
    }
    return lineNumbers
}

func writeStringsFile(entries: [String: String], comments: [String: String?], to url: URL) throws {
    var lines: [String] = []
    let keys = entries.keys.sorted()
    for key in keys {
        let value = entries[key] ?? ""
        // Skip placeholder-style empty pairs so `to-lproj` does not emit
        // meaningless `"" = "";` lines into generated `.strings` files.
        if key.isEmpty, value.isEmpty {
            continue
        }
        if let comment = comments[key] ?? nil, !comment.isEmpty {
            lines.append("/* \(comment) */")
        }
        lines.append("\"\(escapeStringsValue(key))\" = \"\(escapeStringsValue(value))\";")
        lines.append("")
    }
    let content = lines.joined(separator: "\n")
    try ensureDirectory(url.deletingLastPathComponent())
    try content.write(to: url, atomically: true, encoding: .utf8)
}
