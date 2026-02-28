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
    let pattern = "^\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*;"
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    var entries: [String: String] = [:]
    content.enumerateLines { line, _ in
        guard let regex = regex else { return }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = regex.firstMatch(in: line, options: [], range: range),
           let keyRange = Range(match.range(at: 1), in: line),
           let valueRange = Range(match.range(at: 2), in: line) {
            let key = unescapeStringsValue(String(line[keyRange]))
            let value = unescapeStringsValue(String(line[valueRange]))
            entries[key] = value
        }
    }
    return StringsFile(entries: entries)
}

func parseStringsFileLineNumbers(at url: URL) -> [String: Int] {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        return [:]
    }
    let pattern = "^\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*;"
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    var lineNumbers: [String: Int] = [:]
    let lines = content.components(separatedBy: .newlines)
    for (index, line) in lines.enumerated() {
        guard let regex else { continue }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = regex.firstMatch(in: line, options: [], range: range),
           let keyRange = Range(match.range(at: 1), in: line) {
            let key = unescapeStringsValue(String(line[keyRange]))
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
        if let comment = comments[key] ?? nil, !comment.isEmpty {
            lines.append("/* \(comment) */")
        }
        let value = entries[key] ?? ""
        lines.append("\"\(escapeStringsValue(key))\" = \"\(escapeStringsValue(value))\";")
        lines.append("")
    }
    let content = lines.joined(separator: "\n")
    try ensureDirectory(url.deletingLastPathComponent())
    try content.write(to: url, atomically: true, encoding: .utf8)
}
