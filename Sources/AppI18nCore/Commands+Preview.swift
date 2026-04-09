//
//  Commands+Preview.swift
//  appi18n
//
//  Created by wong on 2/28/26.
//

import Foundation

/// A normalized row used by the preview detail table.
/// Each row represents one i18n key after filtering rules are applied.
private struct PreviewRow {
    /// Translation key from `.strings` / `.xcstrings`.
    let key: String
    /// Base language code for this key (for example `en`).
    let defaultLanguage: String
    /// Base language text shown in the "Default Value" column.
    let defaultValue: String
    /// Localized value per language code.
    let valuesByLanguage: [String: String]
    /// Localization state per language code (e.g. `translated`, `new`).
    let statesByLanguage: [String: String]
    /// Optional GitHub source link for each language value cell.
    let sourceLinksByLanguage: [String: String]
}

/// A logical preview unit that corresponds to one `.strings` file.
private struct PreviewFile {
    /// Relative path under `<lang>.lproj` (e.g. `Localizable.strings`).
    let relativePath: String
    /// Base language used by the original `.xcstrings` file.
    let defaultLanguage: String
    /// Render-ready rows for this file.
    let rows: [PreviewRow]
}

/// Aggregated translation progress counters for one language.
private struct LangProgress {
    var translated = 0
    var total = 0
}

/// Render-ready model for one app page and one app section on index.
private struct AppPreview {
    let appName: String
    let pageFileName: String
    let logoPath: String?
    let baseLanguage: String
    /// Number of valid base rows after filtering empty base keys/values.
    let baseTotal: Int
    let languages: [String]
    let files: [PreviewFile]
    let progressByLanguage: [String: LangProgress]
}

/// GitHub context required to build `blob/<commit>/...#L<line>` links.
private struct GitHubBlobContext {
    let repositoryURL: String
    let commitHash: String
}

/// Generate preview HTML files:
/// - `index.html` overview page
/// - one detail page per app
///
/// The method scans `i18n/lproj` for localized `.strings` files and enriches data
/// with `.xcstrings` source language metadata from `i18n/source`.
public func previewHTML(apps: [String]? = nil, outputPath: String = ".html") throws {
    let lprojRoot = i18nLprojURL()
    let sourceRoot = i18nSourceURL()
    let outputDir = URL(fileURLWithPath: outputPath, relativeTo: projectRootURL()).standardizedFileURL
    let logoOutputDir = outputDir.appendingPathComponent("assets/logos")
    let gitHubBlobContext = detectGitHubBlobContext(at: projectRootURL())
    guard let allEntries = try? fileManager.contentsOfDirectory(atPath: lprojRoot.path) else {
        Logger.warn("No lproj directory found at \(lprojRoot.path)")
        return
    }

    let requestedApps = apps?.filter { !$0.isEmpty }
    let appNames = requestedApps ?? allEntries.sorted()
    if appNames.isEmpty {
        Logger.warn("No app found under \(lprojRoot.path)")
        return
    }

    try ensureDirectory(outputDir)
    try ensureDirectory(logoOutputDir)

    var appPreviews: [AppPreview] = []
    var usedPageNames = Set<String>()

    for app in appNames {
        let appLproj = lprojRoot.appendingPathComponent(app)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: appLproj.path, isDirectory: &isDir), isDir.boolValue else {
            Logger.warn("Skip app '\(app)': lproj directory not found at \(appLproj.path)")
            continue
        }

        let langDirs = (try? fileManager.contentsOfDirectory(at: appLproj, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        let langs = langDirs
            .filter { $0.pathExtension == "lproj" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
        if langs.isEmpty { continue }

        var filesByLang: [String: [String: URL]] = [:]
        var allRelFiles = Set<String>()
        for langDir in langDirs where langDir.pathExtension == "lproj" {
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

        var files: [PreviewFile] = []
        var progressByLanguage: [String: LangProgress] = [:]
        var baseTotal = 0

        // Build preview rows file-by-file to preserve original file boundaries.
        for rel in allRelFiles.sorted() {
            let relDir = (rel as NSString).deletingLastPathComponent
            let baseName = (rel as NSString).lastPathComponent.replacingOccurrences(of: ".strings", with: ".xcstrings")
            let xcFile = sourceRoot
                .appendingPathComponent(app)
                .appendingPathComponent(relDir)
                .appendingPathComponent(baseName)

            var sourceLanguage = "en"
            var sourceValuesByKey: [String: String] = [:]
            var statesByLangByKey: [String: [String: String]] = [:]
            // Load source-language values and states from `.xcstrings` when available.
            // When unavailable, we still render based on `.strings` union.
            if fileManager.fileExists(atPath: xcFile.path) {
                let xc = try loadXCStrings(at: xcFile)
                sourceLanguage = xc.sourceLanguage
                for (key, entry) in xc.strings {
                    sourceValuesByKey[key] = getLocalizationValue(entry, lang: sourceLanguage) ?? key
                    if let localizations = entry["localizations"] as? [String: Any] {
                        var keyStates: [String: String] = [:]
                        for (lang, object) in localizations {
                            guard let langObj = object as? [String: Any],
                                  let unit = langObj["stringUnit"] as? [String: Any],
                                  let state = unit["state"] as? String else { continue }
                            keyStates[lang] = state
                        }
                        if !keyStates.isEmpty {
                            statesByLangByKey[key] = keyStates
                        }
                    }
                }
            }

            var keys = Set(sourceValuesByKey.keys)
            var valuesByLang: [String: [String: String]] = [:]
            var lineNumbersByLang: [String: [String: Int]] = [:]
            // Parse `.strings` content and key line numbers for link generation.
            for lang in langs {
                if let file = filesByLang[lang]?[rel] {
                    let entries = parseStringsFile(at: file).entries
                    let lineNumbers = parseStringsFileLineNumbers(at: file)
                    keys.formUnion(entries.keys)
                    valuesByLang[lang] = entries
                    lineNumbersByLang[lang] = lineNumbers
                }
            }

            var rows: [PreviewRow] = []
            for key in keys.sorted() {
                let baseKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseValue = (sourceValuesByKey[key] ?? valuesByLang[sourceLanguage]?[key] ?? key)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Hard filter:
                // - empty key OR empty base value => hide row entirely
                // This row should not appear in detail table and should not affect progress.
                if baseKey.isEmpty || baseValue.isEmpty {
                    continue
                }
                let defaultValue = sourceValuesByKey[key] ?? valuesByLang[sourceLanguage]?[key] ?? key
                var rowValuesByLanguage: [String: String] = [:]
                var rowStatesByLanguage: [String: String] = [:]
                var rowLinksByLanguage: [String: String] = [:]

                for lang in langs {
                    let value = valuesByLang[lang]?[key] ?? ""
                    rowValuesByLanguage[lang] = value
                    if let state = statesByLangByKey[key]?[lang] {
                        rowStatesByLanguage[lang] = state
                    }
                    // Attach source link for this language cell when:
                    // 1) git/github context is available
                    // 2) this key has a known line in the `.strings` file
                    if let gitHubBlobContext,
                       let line = lineNumbersByLang[lang]?[key] {
                        let repoPath = "i18n/lproj/\(app)/\(lang).lproj/\(rel)"
                        rowLinksByLanguage[lang] = makeGitHubBlobLineURL(
                            context: gitHubBlobContext,
                            repositoryRelativePath: repoPath,
                            line: line
                        )
                    }
                    // Base language is excluded from "translated/total" progress counters.
                    if lang == sourceLanguage { continue }
                    var progress = progressByLanguage[lang] ?? LangProgress()
                    progress.total += 1
                    if isCompletedTranslation(value: value, defaultValue: defaultValue, state: rowStatesByLanguage[lang]) {
                        progress.translated += 1
                    }
                    progressByLanguage[lang] = progress
                }

                rows.append(
                    PreviewRow(
                        key: key,
                        defaultLanguage: sourceLanguage,
                        defaultValue: defaultValue,
                        valuesByLanguage: rowValuesByLanguage,
                        statesByLanguage: rowStatesByLanguage,
                        sourceLinksByLanguage: rowLinksByLanguage
                    )
                )
            }
            files.append(PreviewFile(relativePath: rel, defaultLanguage: sourceLanguage, rows: rows))
            baseTotal += rows.count
        }

        let pageFileName = uniqueAppPageFileName(appName: app, usedNames: &usedPageNames)
        let logoFile = sourceRoot.appendingPathComponent(app).appendingPathComponent("logo.png")
        let logoPath: String?
        if fileManager.fileExists(atPath: logoFile.path) {
            let logoFileName = pageFileName.replacingOccurrences(of: ".html", with: ".png")
            let copiedLogo = logoOutputDir.appendingPathComponent(logoFileName)
            try copyFile(logoFile, to: copiedLogo)
            logoPath = "assets/logos/\(logoFileName)"
        } else {
            logoPath = nil
        }
        let baseLanguage = files.first?.defaultLanguage ?? langs.first ?? "en"
        appPreviews.append(
            AppPreview(
                appName: app,
                pageFileName: pageFileName,
                logoPath: logoPath,
                baseLanguage: baseLanguage,
                baseTotal: baseTotal,
                languages: langs,
                files: files,
                progressByLanguage: progressByLanguage
            )
        )
    }

    if appPreviews.isEmpty {
        Logger.warn("No app preview data generated.")
        return
    }

    let indexURL = outputDir.appendingPathComponent("index.html")
    let cssURL = outputDir.appendingPathComponent("preview.css")
    let cssContent = renderPreviewCSS()
    try cssContent.write(to: cssURL, atomically: true, encoding: .utf8)
    let indexHTML = renderPreviewIndexHTML(apps: appPreviews)
    try indexHTML.write(to: indexURL, atomically: true, encoding: .utf8)

    for app in appPreviews {
        let pageURL = outputDir.appendingPathComponent(app.pageFileName)
        let pageHTML = renderPreviewAppHTML(app: app)
        try pageHTML.write(to: pageURL, atomically: true, encoding: .utf8)
    }
    Logger.info("Generated HTML preview index: \(indexURL.path)")
}

/// Translation completion rule:
/// - Explicit `state == translated` always counts as translated
/// - Otherwise non-empty value different from base value counts as translated
private func isCompletedTranslation(value: String, defaultValue: String, state: String?) -> Bool {
    if let state, state.lowercased() == "translated" { return true }
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
    return value != defaultValue
}

/// Escape text for safe HTML embedding.
private func htmlEscape(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

private func relativeURLPath(from baseDirectory: URL, to target: URL) -> String {
    let baseParts = baseDirectory.standardizedFileURL.path.split(separator: "/").map(String.init)
    let targetParts = target.standardizedFileURL.path.split(separator: "/").map(String.init)
    var sharedCount = 0
    while sharedCount < baseParts.count &&
            sharedCount < targetParts.count &&
            baseParts[sharedCount] == targetParts[sharedCount] {
        sharedCount += 1
    }
    let upward = Array(repeating: "..", count: baseParts.count - sharedCount)
    let downward = Array(targetParts.dropFirst(sharedCount))
    let parts = (upward + downward).map {
        $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0
    }
    return parts.isEmpty ? "." : parts.joined(separator: "/")
}

private func appMonogram(_ appName: String) -> String {
    let tokens = appName
        .split { !$0.isLetter && !$0.isNumber }
        .map(String.init)
        .filter { !$0.isEmpty }
    let letters = tokens.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }
    if !letters.isEmpty {
        return letters.joined()
    }
    return String(appName.prefix(2)).uppercased()
}

/// Convert an arbitrary app name/path-like string to a URL-safe slug.
private func safeSlug(_ text: String) -> String {
    let lower = text.lowercased()
    var out = ""
    var prevDash = false
    for ch in lower {
        if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" {
            out.append(ch)
            prevDash = false
            continue
        }
        if !prevDash {
            out.append("-")
            prevDash = true
        }
    }
    let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return trimmed.isEmpty ? "app" : trimmed
}

/// Ensure per-app output filenames are unique on the generated site.
private func uniqueAppPageFileName(appName: String, usedNames: inout Set<String>) -> String {
    let base = safeSlug(appName)
    var candidate = base
    var index = 2
    while usedNames.contains(candidate) {
        candidate = "\(base)-\(index)"
        index += 1
    }
    usedNames.insert(candidate)
    return "\(candidate).html"
}

/// Keep old helper for compatibility with existing UI chips/style decisions.
/// Not all renderers use this directly anymore.
private func percentText(_ progress: LangProgress?) -> String {
    guard let progress, progress.total > 0 else { return "-" }
    let percent = (Double(progress.translated) / Double(progress.total)) * 100.0
    return String(format: "%.1f%%", percent)
}

/// Format completion text as `XX% (translated/total)`.
private func completionRatioText(translated: Int, total: Int) -> String {
    let percent: Int
    if total <= 0 {
        percent = 0
    } else {
        percent = Int((Double(translated) * 100.0 / Double(total)).rounded())
    }
    return "\(percent)% (\(translated)/\(total))"
}

/// Return CSS class for completion color state:
/// - full   => green
/// - zero   => red
/// - partial=> yellow
private func completionClass(translated: Int, total: Int) -> String {
    guard total > 0 else { return "completion-zero" }
    if translated == 0 { return "completion-zero" }
    if translated >= total { return "completion-full" }
    return "completion-partial"
}

/// Render language label with localized display name.
/// Example: `English(en)` or `Japanese(ja)`.
private func localizedLanguageLabel(_ code: String) -> String {
    let lookup = code.replacingOccurrences(of: "-", with: "_")
    let name = Locale.current.localizedString(forIdentifier: lookup) ?? code
    return "\(name)(\(code))"
}

/// Small command runner used only for lightweight git probes in preview generation.
/// Returns `(exitStatus, trimmedStdout)`.
private func runCommand(_ executable: String, _ arguments: [String], currentDirectory: URL) -> (Int32, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectory

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = Pipe()
    do {
        try process.run()
    } catch {
        return (-1, "")
    }
    process.waitUntilExit()
    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let text = String(data: data, encoding: .utf8) ?? ""
    return (process.terminationStatus, text.trimmingCharacters(in: .whitespacesAndNewlines))
}

/// Detect GitHub repository + current commit for building source links.
/// Returns `nil` when git is unavailable, origin is missing, or remote is not GitHub.
private func detectGitHubBlobContext(at root: URL) -> GitHubBlobContext? {
    let gitCheck = runCommand("/usr/bin/env", ["git", "--version"], currentDirectory: root)
    guard gitCheck.0 == 0 else { return nil }

    let remoteOutput = runCommand("/usr/bin/env", ["git", "remote", "get-url", "origin"], currentDirectory: root)
    guard remoteOutput.0 == 0, !remoteOutput.1.isEmpty else { return nil }

    let commitOutput = runCommand("/usr/bin/env", ["git", "rev-parse", "HEAD"], currentDirectory: root)
    guard commitOutput.0 == 0, !commitOutput.1.isEmpty else { return nil }

    guard let repositoryURL = normalizedGitHubRepositoryURL(remoteURL: remoteOutput.1) else { return nil }
    return GitHubBlobContext(repositoryURL: repositoryURL, commitHash: commitOutput.1)
}

/// Normalize common Git remote URL formats into `https://github.com/owner/repo`.
/// Supported examples:
/// - `git@github.com:owner/repo.git`
/// - `ssh://git@github.com/owner/repo.git`
/// - `https://github.com/owner/repo(.git)`
private func normalizedGitHubRepositoryURL(remoteURL: String) -> String? {
    let raw = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.hasPrefix("git@github.com:") {
        let path = String(raw.dropFirst("git@github.com:".count))
        return "https://github.com/" + path.replacingOccurrences(of: ".git", with: "")
    }
    if raw.hasPrefix("ssh://git@github.com/") {
        let path = String(raw.dropFirst("ssh://git@github.com/".count))
        return "https://github.com/" + path.replacingOccurrences(of: ".git", with: "")
    }
    guard let url = URL(string: raw),
          let host = url.host?.lowercased(),
          host == "github.com" else {
        return nil
    }
    let path = url.path.replacingOccurrences(of: ".git", with: "")
    return "https://github.com\(path)"
}

/// Build a deep link to a specific file line on GitHub for current commit.
private func makeGitHubBlobLineURL(context: GitHubBlobContext, repositoryRelativePath: String, line: Int) -> String {
    let encodedPath = repositoryRelativePath
        .split(separator: "/")
        .map { component in
            String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
        }
        .joined(separator: "/")
    return "\(context.repositoryURL)/blob/\(context.commitHash)/\(encodedPath)#L\(line)"
}

/// Render overview index page with one table per app.
private func renderPreviewIndexHTML(apps: [AppPreview]) -> String {
    let generatedAt = ISO8601DateFormatter().string(from: Date())
    var appTables: [String] = []
    for app in apps.sorted(by: { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }) {
        let langs = app.languages.sorted()
        var langRows: [String] = []
        for lang in langs {
            let completion: String
            let completionClassName: String
            let translated: Int
            let total: Int
            if lang == app.baseLanguage {
                total = app.baseTotal
                translated = total
                completion = completionRatioText(translated: translated, total: total)
                completionClassName = completionClass(translated: translated, total: total)
            } else {
                let progress = app.progressByLanguage[lang] ?? LangProgress()
                translated = progress.translated
                total = progress.total
                completion = completionRatioText(translated: translated, total: total)
                completionClassName = completionClass(translated: translated, total: total)
            }
            let ratioPercent = total > 0 ? Int((Double(translated) * 100.0 / Double(total)).rounded()) : 0
            langRows.append(
                """
                <li class="language-row">
                  <div class="language-row-head">
                    <span class="language-name">\(htmlEscape(localizedLanguageLabel(lang)))</span>
                    <span class="language-ratio \(completionClassName)">\(htmlEscape(completion))</span>
                  </div>
                  <div class="progress-track">
                    <span class="progress-fill \(completionClassName)" style="width: \(ratioPercent)%"></span>
                  </div>
                </li>
                """
            )
        }
        let logoMarkup: String
        if let logoPath = app.logoPath {
            logoMarkup = "<img class=\"app-logo\" src=\"\(htmlEscape(logoPath))\" alt=\"\(htmlEscape(app.appName)) logo\">"
        } else {
            logoMarkup = "<div class=\"app-logo app-logo-fallback\">\(htmlEscape(appMonogram(app.appName)))</div>"
        }
        appTables.append(
            """
            <section class="app-block app-card">
              <div class="app-header">
                <div class="app-brand">
                  \(logoMarkup)
                  <div>
                    <p class="eyebrow">i18n Preview</p>
                    <h2><a href="\(htmlEscape(app.pageFileName))">\(htmlEscape(app.appName))</a></h2>
                  </div>
                </div>
                <div class="app-meta">
                  <span class="meta-pill">Base \(htmlEscape(app.baseLanguage))</span>
                  <span class="meta-pill">Files \(app.files.count)</span>
                </div>
              </div>
              <div class="table-wrap card-table">
                <ul class="language-list">
                  \(langRows.joined(separator: "\n"))
                </ul>
              </div>
            </section>
            """
        )
    }

    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>My App i18n Preview</title>
      <link rel="stylesheet" href="preview.css">
    </head>
    <body>
      <div class="wrap">
        <section class="hero">
          <h1>My App i18n Preview</h1>
          <p class="hero-copy">A visual index of translation coverage across your apps. Each card links to a detailed per-file matrix, with language progress surfaced directly on the front page.</p>
          <p class="meta">Generated at: \(htmlEscape(generatedAt)) · Apps: \(apps.count)</p>
        </section>
        <section class="apps-grid">
          \(appTables.joined(separator: "\n"))
        </section>
      </div>
    </body>
    </html>
    """
}

/// Render detail page for one app, including file switcher and per-language table.
private func renderPreviewAppHTML(app: AppPreview) -> String {
    let generatedAt = ISO8601DateFormatter().string(from: Date())
    let languages = app.languages

    var summaryChips: [String] = []
    for lang in languages {
        let completion: String
        if lang == app.baseLanguage {
            let total = app.baseTotal
            completion = completionRatioText(translated: total, total: total)
        } else {
            let progress = app.progressByLanguage[lang] ?? LangProgress()
            completion = completionRatioText(translated: progress.translated, total: progress.total)
        }
        summaryChips.append("<span class=\"chip\">\(htmlEscape(lang)): \(htmlEscape(completion))</span>")
    }

    var selectOptions: [String] = []
    var panels: [String] = []
    for (index, file) in app.files.enumerated() {
        let panelID = "file-" + safeSlug(file.relativePath)
        let activeClass = index == 0 ? " active" : ""
        let selected = index == 0 ? " selected" : ""
        selectOptions.append("<option value=\"\(htmlEscape(panelID))\"\(selected)>\(htmlEscape(file.relativePath))</option>")

        var headerCells = """
    <th>Key</th>
    <th>Default Value (\(htmlEscape(file.defaultLanguage)))</th>
    """
        let displayedLanguages = languages.filter { $0 != file.defaultLanguage }
        for lang in displayedLanguages {
            headerCells += "\n<th>\(htmlEscape(lang))</th>"
        }

        var bodyRows: [String] = []
        for row in file.rows {
            var tds = """
        <td><code>\(htmlEscape(row.key))</code></td>
        <td>\(htmlEscape(row.defaultValue))</td>
        """
            for lang in displayedLanguages {
                let value = row.valuesByLanguage[lang] ?? ""
                let completed = isCompletedTranslation(
                    value: value,
                    defaultValue: row.defaultValue,
                    state: row.statesByLanguage[lang]
                )
                let cssClass = completed ? "ok" : "todo"
                if let link = row.sourceLinksByLanguage[lang], !value.isEmpty {
                    tds += "\n<td class=\"\(cssClass)\"><a class=\"cell-link\" href=\"\(htmlEscape(link))\" target=\"_blank\" rel=\"noreferrer noopener\">\(htmlEscape(value))</a></td>"
                } else {
                    tds += "\n<td class=\"\(cssClass)\">\(htmlEscape(value))</td>"
                }
            }
            bodyRows.append("<tr>\n\(tds)\n</tr>")
        }

        panels.append(
            """
            <section id="\(htmlEscape(panelID))" class="panel\(activeClass)">
              <h3>\(htmlEscape(file.relativePath))</h3>
              <div class="table-wrap">
                <table>
                  <thead>
                    <tr>\(headerCells)</tr>
                  </thead>
                  <tbody>
                    \(bodyRows.joined(separator: "\n"))
                  </tbody>
                </table>
              </div>
            </section>
            """
        )
    }
    let logoMarkup: String
    if let logoPath = app.logoPath {
        logoMarkup = "<img class=\"app-logo\" src=\"\(htmlEscape(logoPath))\" alt=\"\(htmlEscape(app.appName)) logo\">"
    } else {
        logoMarkup = "<div class=\"app-logo app-logo-fallback\">\(htmlEscape(appMonogram(app.appName)))</div>"
    }

    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(htmlEscape(app.appName)) i18n Preview</title>
      <link rel="stylesheet" href="preview.css">
    </head>
    <body>
      <div class="wrap">
        <a class="back" href="index.html">← Back to index</a>
        <section class="hero">
          <div class="hero-head">
            \(logoMarkup)
            <div>
              <h1>\(htmlEscape(app.appName))</h1>
              <p class="meta">Generated at: \(htmlEscape(generatedAt)) · Files: \(app.files.count)</p>
            </div>
          </div>
        <div class="chips">
          \(summaryChips.joined(separator: "\n"))
        </div>
        </section>
        <div class="toolbar">
          <select id="file-select" class="file-select">
            \(selectOptions.joined(separator: "\n"))
          </select>
        </div>
        <div class="content">
          \(panels.joined(separator: "\n"))
        </div>
      </div>
      <script>
        (function () {
          const select = document.getElementById('file-select');
          const panels = document.querySelectorAll('.panel');
          function activate(target) {
            panels.forEach((panel) => panel.classList.toggle('active', panel.id === target));
            if (select) select.value = target;
          }
          if (select) {
            select.addEventListener('change', function () { activate(select.value); });
          }
          if (select && panels.length > 0) {
            activate(select.value);
          }
        })();
      </script>
    </body>
    </html>
    """
}

private func renderPreviewCSS() -> String {
    """
    :root {
      --bg: #060708;
      --surface: rgba(15,17,20,0.84);
      --surface-strong: rgba(19,22,26,0.96);
      --ink: #eef2f6;
      --muted: #93a0ad;
      --line: rgba(255,255,255,0.08);
      --accent: #8fd0bb;
      --accent-soft: rgba(143,208,187,0.14);
      --shadow: 0 14px 32px rgba(0, 0, 0, 0.28);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      font-family: "Avenir Next", "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at top left, rgba(103, 142, 255, 0.14), transparent 28%),
        radial-gradient(circle at top right, rgba(85, 192, 154, 0.1), transparent 30%),
        linear-gradient(180deg, #0b0d10 0%, #08090b 52%, #050608 100%);
    }
    .wrap { max-width: 1240px; margin: 0 auto; padding: 24px 18px 42px; }
    h1 { margin: 0 0 8px; font-size: clamp(30px, 5vw, 52px); line-height: 0.98; letter-spacing: -0.05em; }
    h2 { margin: 0; font-size: 23px; line-height: 1.1; letter-spacing: -0.03em; }
    h3 { margin: 0 0 8px; font-size: 14px; }
    .hero-copy {
      max-width: 760px;
      margin: 0 0 14px;
      color: var(--muted);
      font-size: 15px;
      line-height: 1.7;
    }
    .meta { margin: 0 0 10px; color: var(--muted); font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; }
    .hero {
      margin-bottom: 16px;
      padding: 20px 24px;
      border: 1px solid rgba(255,255,255,0.09);
      border-radius: 16px;
      background: linear-gradient(135deg, rgba(255,255,255,0.035), rgba(255,255,255,0.015));
      box-shadow: var(--shadow);
    }
    .hero-head { display: flex; align-items: center; gap: 16px; margin-bottom: 10px; }
    .apps-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 18px;
    }
    .app-block { margin: 0; }
    .app-card {
      overflow: hidden;
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 16px;
      background: var(--surface);
      backdrop-filter: blur(14px);
      box-shadow: var(--shadow);
    }
    .app-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      padding: 20px 20px 16px;
      border-bottom: 1px solid var(--line);
    }
    .app-brand { display: flex; align-items: center; gap: 14px; min-width: 0; }
    .app-logo {
      width: 64px;
      height: 64px;
      flex: none;
      border-radius: 14px;
      object-fit: cover;
      box-shadow: 0 8px 20px rgba(0, 0, 0, 0.22);
      background: #101317;
    }
    .hero .app-logo { width: 68px; height: 68px; }
    .app-logo-fallback {
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #203b33, #364b78);
      color: #f5f7fa;
      font-weight: 700;
      letter-spacing: 0.08em;
    }
    .eyebrow {
      margin: 0 0 4px;
      color: var(--muted);
      font-size: 11px;
      letter-spacing: 0.18em;
      text-transform: uppercase;
      white-space: nowrap;
    }
    .app-meta { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; }
    .meta-pill,
    .chip,
    .language-ratio {
      border-radius: 999px;
      border: 1px solid var(--line);
      white-space: nowrap;
    }
    .meta-pill {
      display: inline-flex;
      align-items: center;
      padding: 3px 6px;
      background: rgba(255,255,255,0.04);
      color: var(--muted);
      font-size: 9px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }
    .card-table { margin: 0 16px 16px; padding-top: 15px; }
    .language-list { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
    .language-row {
      padding: 10px 10px 12px;
      border-radius: 10px;
      border: 1px solid rgba(255,255,255,0.05);
      background: rgba(255,255,255,0.02);
    }
    .language-row-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 8px;
    }
    .language-name { color: var(--ink); font-size: 12px; line-height: 1.5; }
    .language-ratio {
      font-size: 11px;
      line-height: 1;
      padding: 5px 7px;
      border-color: transparent;
    }
    .progress-track {
      width: 100%;
      height: 7px;
      overflow: hidden;
      border-radius: 999px;
      background: rgba(255,255,255,0.06);
    }
    .progress-fill {
      display: block;
      height: 100%;
      min-width: 0;
      border-radius: inherit;
    }
    .completion-full { color: #9fe2c2; background: rgba(45, 165, 118, 0.12); border-color: rgba(45, 165, 118, 0.2); }
    .completion-zero { color: #ffb4ba; background: rgba(190, 70, 78, 0.12); border-color: rgba(190, 70, 78, 0.2); }
    .completion-partial { color: #f0d48a; background: rgba(180, 132, 47, 0.12); border-color: rgba(180, 132, 47, 0.2); }
    .progress-fill.completion-full { background: linear-gradient(90deg, rgba(75, 203, 145, 0.75), rgba(128, 232, 188, 0.96)); }
    .progress-fill.completion-zero { background: linear-gradient(90deg, rgba(209, 74, 84, 0.76), rgba(255, 138, 146, 0.96)); }
    .progress-fill.completion-partial { background: linear-gradient(90deg, rgba(184, 131, 38, 0.76), rgba(243, 198, 94, 0.96)); }
    .chips { margin-bottom: 14px; display: flex; flex-wrap: wrap; gap: 8px; }
    .chip {
      display: inline-block;
      padding: 6px 10px;
      font-size: 12px;
      background: rgba(255,255,255,0.04);
      color: #d4dde6;
    }
    .toolbar { display: flex; justify-content: flex-start; align-items: center; margin-bottom: 12px; }
    .file-select {
      border: 1px solid var(--line);
      border-radius: 10px;
      background: rgba(255,255,255,0.04);
      color: var(--ink);
      padding: 8px 10px;
      font-size: 12px;
      min-width: 360px;
      max-width: 100%;
    }
    .panel { display: none; }
    .panel.active { display: block; }
    .table-wrap {
      overflow: auto;
      border-radius: 12px;
    }
    table { border-collapse: collapse; width: 100%; min-width: 820px; }
    th, td {
      border-bottom: 1px solid var(--line);
      border-right: 1px solid var(--line);
      text-align: left;
      vertical-align: top;
      padding: 8px 10px;
      font-size: 12px;
      line-height: 1.5;
    }
    th { position: sticky; top: 0; background: rgba(255,255,255,0.045); z-index: 1; }
    code { white-space: pre-wrap; word-break: break-all; }
    td { white-space: pre-wrap; word-break: break-word; }
    td.ok { background: rgba(45, 165, 118, 0.15); color: #9fe2c2; }
    td.todo { background: rgba(180, 132, 47, 0.16); color: #f0d48a; }
    .cell-link { color: inherit; text-decoration: underline; text-underline-offset: 2px; }
    .back { display: inline-block; margin-bottom: 10px; color: var(--accent); text-decoration: none; }
    .back:hover,
    a:hover { text-decoration: underline; }
    a { color: var(--accent); text-decoration: none; }
    @media (max-width: 900px) {
      .toolbar { justify-content: stretch; }
      .file-select { min-width: 0; width: 100%; }
      .hero-head { align-items: flex-start; }
    }
    @media (max-width: 760px) {
      .hero { padding: 20px; border-radius: 16px; }
      .app-header { flex-direction: column; }
      .app-meta { justify-content: flex-start; }
    }
    """
}
