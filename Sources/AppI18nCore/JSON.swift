import Foundation

func readJSON(from url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    let obj = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers, .mutableLeaves])
    guard let dict = obj as? [String: Any] else {
        throw AppError.message("Invalid JSON: \(url.path)")
    }
    return dict
}

func writeJSON(_ dict: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

func loadXCStrings(at url: URL) throws -> XCStringsFile {
    let raw = try readJSON(from: url)
    guard let strings = raw["strings"] as? [String: Any] else {
        throw AppError.message("Missing 'strings' in \(url.path)")
    }
    let sourceLanguage = (raw["sourceLanguage"] as? String) ?? "en"
    let version = raw["version"] as? String
    var typedStrings: [String: [String: Any]] = [:]
    for (key, value) in strings {
        if let entry = value as? [String: Any] {
            typedStrings[key] = entry
        }
    }
    return XCStringsFile(sourceLanguage: sourceLanguage, version: version, strings: typedStrings, raw: raw)
}

func extractLanguages(from xc: XCStringsFile) -> [String] {
    var langs = Set<String>()
    langs.insert(xc.sourceLanguage)
    for (_, entry) in xc.strings {
        if let locs = entry["localizations"] as? [String: Any] {
            for lang in locs.keys { langs.insert(lang) }
        }
    }
    return Array(langs).sorted()
}

func getLocalizationValue(_ entry: [String: Any], lang: String) -> String? {
    guard let locs = entry["localizations"] as? [String: Any],
          let langObj = locs[lang] as? [String: Any],
          let unit = langObj["stringUnit"] as? [String: Any] else {
        return nil
    }
    return unit["value"] as? String
}

func getEntryComment(_ entry: [String: Any]) -> String? {
    return entry["comment"] as? String
}
