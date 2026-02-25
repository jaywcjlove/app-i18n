import Foundation

public func extract(projectPath: String) throws {
    let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL
    let appName = projectURL.lastPathComponent
    let targetRoot = i18nSourceURL().appendingPathComponent(appName)
    let files = listFiles(withExtension: "xcstrings", under: projectURL)
    if files.isEmpty {
        Logger.warn("No .xcstrings found under \(projectURL.path)")
        return
    }
    for file in files {
        let rel = relativePath(from: projectURL, to: file)
        let dst = targetRoot.appendingPathComponent(rel)
        try copyFile(file, to: dst)
    }
    Logger.info("Extracted \(files.count) .xcstrings to \(targetRoot.path)")
}

public func toLproj() throws {
    let sourceRoot = i18nSourceURL()
    let lprojRoot = i18nLprojURL()
    guard let apps = try? fileManager.contentsOfDirectory(atPath: sourceRoot.path) else {
        Logger.warn("No source directory found at \(sourceRoot.path)")
        return
    }
    for app in apps {
        let appSource = sourceRoot.appendingPathComponent(app)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: appSource.path, isDirectory: &isDir), isDir.boolValue else { continue }
        let xcFiles = listFiles(withExtension: "xcstrings", under: appSource)
        for xcFile in xcFiles {
            let xc = try loadXCStrings(at: xcFile)
            let languages = extractLanguages(from: xc)
            let rel = relativePath(from: appSource, to: xcFile)
            let relDir = (rel as NSString).deletingLastPathComponent
            let baseName = (rel as NSString).lastPathComponent.replacingOccurrences(of: ".xcstrings", with: ".strings")

            var comments: [String: String?] = [:]
            for (key, entry) in xc.strings {
                comments[key] = getEntryComment(entry)
            }

            for lang in languages {
                let langDir = lprojRoot
                    .appendingPathComponent(app)
                    .appendingPathComponent("\(lang).lproj")
                let targetDir = langDir.appendingPathComponent(relDir)
                let targetFile = targetDir.appendingPathComponent(baseName)

                let existing = parseStringsFile(at: targetFile)
                var merged = existing.entries

                for (key, entry) in xc.strings {
                    if merged[key] != nil { continue }
                    let defaultValue = getLocalizationValue(entry, lang: xc.sourceLanguage).flatMap { $0.isEmpty ? nil : $0 } ?? key
                    let value = getLocalizationValue(entry, lang: lang)
                    if let v = value, !v.isEmpty {
                        merged[key] = v
                    } else {
                        merged[key] = defaultValue
                    }
                }

                try writeStringsFile(entries: merged, comments: comments, to: targetFile)
            }
        }
    }
    Logger.info("Converted .xcstrings to .lproj")
}

public func addLanguage(app: String, lang: String) throws {
    let sourceRoot = i18nSourceURL()
    let lprojRoot = i18nLprojURL()
    let appSource = sourceRoot.appendingPathComponent(app)
    var isDir: ObjCBool = false
    guard fileManager.fileExists(atPath: appSource.path, isDirectory: &isDir), isDir.boolValue else {
        throw AppError.message("App source not found: \(appSource.path)")
    }
    guard let apps = try? fileManager.contentsOfDirectory(atPath: sourceRoot.path) else {
        Logger.warn("No source directory found at \(sourceRoot.path)")
        return
    }
    for app in apps where app == appSource.lastPathComponent {
        let xcFiles = listFiles(withExtension: "xcstrings", under: appSource)
        for xcFile in xcFiles {
            let xc = try loadXCStrings(at: xcFile)
            let rel = relativePath(from: appSource, to: xcFile)
            let relDir = (rel as NSString).deletingLastPathComponent
            let baseName = (rel as NSString).lastPathComponent.replacingOccurrences(of: ".xcstrings", with: ".strings")

            var comments: [String: String?] = [:]
            for (key, entry) in xc.strings {
                comments[key] = getEntryComment(entry)
            }

            let langDir = lprojRoot
                .appendingPathComponent(app)
                .appendingPathComponent("\(lang).lproj")
            let targetDir = langDir.appendingPathComponent(relDir)
            let targetFile = targetDir.appendingPathComponent(baseName)

            let existing = parseStringsFile(at: targetFile)
            var merged = existing.entries

            for (key, entry) in xc.strings {
                if merged[key] != nil { continue }
                let defaultValue = getLocalizationValue(entry, lang: xc.sourceLanguage).flatMap { $0.isEmpty ? nil : $0 } ?? key
                let value = getLocalizationValue(entry, lang: lang)
                if let v = value, !v.isEmpty {
                    merged[key] = v
                } else {
                    merged[key] = defaultValue
                }
            }

            try writeStringsFile(entries: merged, comments: comments, to: targetFile)
        }
    }
    Logger.info("Added language \(lang) to .lproj")
}

public func toXCStrings() throws {
    let sourceRoot = i18nSourceURL()
    let lprojRoot = i18nLprojURL()
    guard let apps = try? fileManager.contentsOfDirectory(atPath: lprojRoot.path) else {
        Logger.warn("No lproj directory found at \(lprojRoot.path)")
        return
    }
    for app in apps {
        let appLproj = lprojRoot.appendingPathComponent(app)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: appLproj.path, isDirectory: &isDir), isDir.boolValue else { continue }

        let langDirs = (try? fileManager.contentsOfDirectory(at: appLproj, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        for langDir in langDirs where langDir.pathExtension == "lproj" {
            let lang = langDir.deletingPathExtension().lastPathComponent
            let stringsFiles = listFiles(withExtension: "strings", under: langDir)
            for stringsFile in stringsFiles {
                let rel = relativePath(from: langDir, to: stringsFile)
                let relDir = (rel as NSString).deletingLastPathComponent
                let baseName = (rel as NSString).lastPathComponent.replacingOccurrences(of: ".strings", with: ".xcstrings")
                let xcFile = sourceRoot
                    .appendingPathComponent(app)
                    .appendingPathComponent(relDir)
                    .appendingPathComponent(baseName)

                if !fileManager.fileExists(atPath: xcFile.path) {
                    Logger.warn("Missing xcstrings file: \(xcFile.path)")
                    continue
                }

                var xc = try loadXCStrings(at: xcFile)
                let strings = parseStringsFile(at: stringsFile)
                for (key, value) in strings.entries {
                    if value.isEmpty { continue }
                    var entry = xc.strings[key] ?? [:]
                    var localizations = entry["localizations"] as? [String: Any] ?? [:]
                    var langObj = localizations[lang] as? [String: Any] ?? [:]
                    var unit = langObj["stringUnit"] as? [String: Any] ?? [:]
                    unit["value"] = value
                    if unit["state"] == nil {
                        unit["state"] = (lang == xc.sourceLanguage) ? "new" : "translated"
                    }
                    langObj["stringUnit"] = unit
                    localizations[lang] = langObj
                    entry["localizations"] = localizations
                    xc.strings[key] = entry
                }

                xc.raw["strings"] = xc.strings
                xc.raw["sourceLanguage"] = xc.sourceLanguage
                if let version = xc.version { xc.raw["version"] = version }
                try writeJSON(xc.raw, to: xcFile)
            }
        }
    }
    Logger.info("Updated .xcstrings from .lproj")
}

public func status() throws {
    let lprojRoot = i18nLprojURL()
    guard let apps = try? fileManager.contentsOfDirectory(atPath: lprojRoot.path) else {
        Logger.warn("No lproj directory found at \(lprojRoot.path)")
        return
    }
    var hasIssues = false
    for app in apps {
        let appLproj = lprojRoot.appendingPathComponent(app)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: appLproj.path, isDirectory: &isDir), isDir.boolValue else { continue }
        let langDirs = (try? fileManager.contentsOfDirectory(at: appLproj, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        let langs = langDirs.filter { $0.pathExtension == "lproj" }
        var filesByLang: [String: [String: URL]] = [:]
        var allRelFiles = Set<String>()

        for langDir in langs {
            let lang = langDir.deletingPathExtension().lastPathComponent
            let stringsFiles = listFiles(withExtension: "strings", under: langDir)
            var relMap: [String: URL] = [:]
            for file in stringsFiles {
                let rel = relativePath(from: langDir, to: file)
                relMap[rel] = file
                allRelFiles.insert(rel)
            }
            filesByLang[lang] = relMap
        }

        for rel in allRelFiles.sorted() {
            var unionKeys = Set<String>()
            var valuesByLang: [String: [String: String]] = [:]
            for (lang, relMap) in filesByLang {
                if let file = relMap[rel] {
                    let parsed = parseStringsFile(at: file)
                    unionKeys.formUnion(parsed.entries.keys)
                    valuesByLang[lang] = parsed.entries
                }
            }

            for (lang, relMap) in filesByLang {
                if relMap[rel] == nil {
                    hasIssues = true
                    Logger.info("[missing] \(app) \(lang): \(rel)")
                    continue
                }
                let entries = valuesByLang[lang] ?? [:]
                for key in unionKeys {
                    if entries[key] == nil {
                        hasIssues = true
                        Logger.info("[incomplete] \(app) \(lang): \(rel) missing key \(key)")
                    } else if entries[key]?.isEmpty == true {
                        hasIssues = true
                        Logger.info("[incomplete] \(app) \(lang): \(rel) empty value for key \(key)")
                    }
                }
            }
        }
    }
    if !hasIssues {
        Logger.info("All translations look complete.")
    }
}

public func clean() throws {
    let lprojRoot = i18nLprojURL()
    guard let apps = try? fileManager.contentsOfDirectory(atPath: lprojRoot.path) else {
        Logger.warn("No lproj directory found at \(lprojRoot.path)")
        return
    }
    var removedFiles = 0
    for app in apps {
        let appLproj = lprojRoot.appendingPathComponent(app)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: appLproj.path, isDirectory: &isDir), isDir.boolValue else { continue }
        let langDirs = (try? fileManager.contentsOfDirectory(at: appLproj, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        for langDir in langDirs where langDir.pathExtension == "lproj" {
            let stringsFiles = listFiles(withExtension: "strings", under: langDir)
            for file in stringsFiles {
                let parsed = parseStringsFile(at: file)
                if parsed.entries.isEmpty {
                    try fileManager.removeItem(at: file)
                    removedFiles += 1
                }
            }
        }
    }

    func removeEmptyDirectories(at url: URL) {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles], errorHandler: nil) else { return }
        var dirs: [URL] = []
        for case let dirURL as URL in enumerator {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue {
                dirs.append(dirURL)
            }
        }
        for dir in dirs.sorted(by: { $0.path.count > $1.path.count }) {
            if (try? fileManager.contentsOfDirectory(atPath: dir.path)).map({ $0.isEmpty }) ?? false {
                try? fileManager.removeItem(at: dir)
            }
        }
    }

    removeEmptyDirectories(at: lprojRoot)
    Logger.info("Cleaned \(removedFiles) empty .strings files")
}

public func listLanguages() throws {
    let lprojRoot = i18nLprojURL()
    guard let apps = try? fileManager.contentsOfDirectory(atPath: lprojRoot.path) else {
        Logger.warn("No lproj directory found at \(lprojRoot.path)")
        return
    }
    var langs = Set<String>()
    for app in apps {
        let appLproj = lprojRoot.appendingPathComponent(app)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: appLproj.path, isDirectory: &isDir), isDir.boolValue else { continue }
        let langDirs = (try? fileManager.contentsOfDirectory(at: appLproj, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        for dir in langDirs where dir.pathExtension == "lproj" {
            langs.insert(dir.deletingPathExtension().lastPathComponent)
        }
    }
    let sorted = langs.sorted()
    if sorted.isEmpty {
        Logger.info("No languages found.")
        return
    }
    sorted.forEach { Logger.info($0) }
}

public func listLanguages(app: String) throws {
    let langs = try getLanguages(app: app)
    if langs.isEmpty {
        Logger.info("No languages found for \(app)")
        return
    }
    langs.forEach { Logger.info($0) }
}

public func getLanguages(app: String) throws -> [String] {
    let lprojRoot = i18nLprojURL()
    let appLproj = lprojRoot.appendingPathComponent(app)
    var isDir: ObjCBool = false
    guard fileManager.fileExists(atPath: appLproj.path, isDirectory: &isDir), isDir.boolValue else {
        throw AppError.message("App lproj not found: \(appLproj.path)")
    }
    let langDirs = (try? fileManager.contentsOfDirectory(at: appLproj, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    return langDirs
        .filter { $0.pathExtension == "lproj" }
        .map { $0.deletingPathExtension().lastPathComponent }
        .sorted()
}

public func listSupportedLanguages(all: Bool) {
    func displayName(for code: String) -> String {
        let locale = Locale.current
        let lookup = code.replacingOccurrences(of: "-", with: "_")
        return locale.localizedString(forIdentifier: lookup) ?? code
    }

    if all {
        let langs = Set(Locale.availableIdentifiers.map { $0.replacingOccurrences(of: "_", with: "-") })
        langs.sorted().forEach { code in
            Logger.info("\(displayName(for: code)) (\(code))")
        }
        return
    }
    let common: [String] = [
        "ar",
        "bg",
        "ca",
        "cs",
        "da",
        "de",
        "el",
        "en",
        "en-AU",
        "en-CA",
        "en-GB",
        "en-US",
        "es",
        "es-419",
        "et",
        "fi",
        "fr",
        "fr-CA",
        "he",
        "hi",
        "hr",
        "hu",
        "id",
        "it",
        "ja",
        "ko",
        "lt",
        "lv",
        "ms",
        "nb",
        "nl",
        "pl",
        "pt",
        "pt-BR",
        "pt-PT",
        "ro",
        "ru",
        "sk",
        "sl",
        "sr",
        "sr-Latn",
        "sv",
        "th",
        "tr",
        "uk",
        "vi",
        "zh-Hans",
        "zh-Hant"
    ]
    common.forEach { code in
        Logger.info("\(displayName(for: code)) (\(code))")
    }
}
