//
//  Commands+Preview.swift
//  appi18n
//
//  Created by wong on 2/28/26.
//

import Foundation

private struct PreviewRow {
    let key: String
    let defaultLanguage: String
    let defaultValue: String
    let valuesByLanguage: [String: String]
    let statesByLanguage: [String: String]
}

private struct PreviewFile {
    let relativePath: String
    let defaultLanguage: String
    let rows: [PreviewRow]
}

private struct LangProgress {
    var translated = 0
    var total = 0
}

private struct AppPreview {
    let appName: String
    let pageFileName: String
    let baseLanguage: String
    let baseTotal: Int
    let languages: [String]
    let files: [PreviewFile]
    let progressByLanguage: [String: LangProgress]
}

public func previewHTML(apps: [String]? = nil, outputPath: String = ".html") throws {
    let lprojRoot = i18nLprojURL()
    let sourceRoot = i18nSourceURL()
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
            for lang in langs {
                if let file = filesByLang[lang]?[rel] {
                    let entries = parseStringsFile(at: file).entries
                    keys.formUnion(entries.keys)
                    valuesByLang[lang] = entries
                }
            }

            var rows: [PreviewRow] = []
            for key in keys.sorted() {
                let baseKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseValue = (sourceValuesByKey[key] ?? valuesByLang[sourceLanguage]?[key] ?? key)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if baseKey.isEmpty || baseValue.isEmpty {
                    continue
                }
                let defaultValue = sourceValuesByKey[key] ?? valuesByLang[sourceLanguage]?[key] ?? key
                var rowValuesByLanguage: [String: String] = [:]
                var rowStatesByLanguage: [String: String] = [:]

                for lang in langs {
                    let value = valuesByLang[lang]?[key] ?? ""
                    rowValuesByLanguage[lang] = value
                    if let state = statesByLangByKey[key]?[lang] {
                        rowStatesByLanguage[lang] = state
                    }
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
                        statesByLanguage: rowStatesByLanguage
                    )
                )
            }
            files.append(PreviewFile(relativePath: rel, defaultLanguage: sourceLanguage, rows: rows))
            baseTotal += rows.count
        }

        let pageFileName = uniqueAppPageFileName(appName: app, usedNames: &usedPageNames)
        let baseLanguage = files.first?.defaultLanguage ?? langs.first ?? "en"
        appPreviews.append(
            AppPreview(
                appName: app,
                pageFileName: pageFileName,
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

    let outputDir = URL(fileURLWithPath: outputPath, relativeTo: projectRootURL()).standardizedFileURL
    try ensureDirectory(outputDir)

    let indexURL = outputDir.appendingPathComponent("index.html")
    let indexHTML = renderPreviewIndexHTML(apps: appPreviews)
    try indexHTML.write(to: indexURL, atomically: true, encoding: .utf8)

    for app in appPreviews {
        let pageURL = outputDir.appendingPathComponent(app.pageFileName)
        let pageHTML = renderPreviewAppHTML(app: app)
        try pageHTML.write(to: pageURL, atomically: true, encoding: .utf8)
    }
    Logger.info("Generated HTML preview index: \(indexURL.path)")
}

private func isCompletedTranslation(value: String, defaultValue: String, state: String?) -> Bool {
    if let state, state.lowercased() == "translated" { return true }
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
    return value != defaultValue
}

private func htmlEscape(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

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

private func percentText(_ progress: LangProgress?) -> String {
    guard let progress, progress.total > 0 else { return "-" }
    let percent = (Double(progress.translated) / Double(progress.total)) * 100.0
    return String(format: "%.1f%%", percent)
}

private func completionRatioText(translated: Int, total: Int) -> String {
    let percent: Int
    if total <= 0 {
        percent = 0
    } else {
        percent = Int((Double(translated) * 100.0 / Double(total)).rounded())
    }
    return "\(percent)% (\(translated)/\(total))"
}

private func localizedLanguageLabel(_ code: String) -> String {
    let lookup = code.replacingOccurrences(of: "-", with: "_")
    let name = Locale.current.localizedString(forIdentifier: lookup) ?? code
    return "\(name)(\(code))"
}

private func renderPreviewIndexHTML(apps: [AppPreview]) -> String {
    let generatedAt = ISO8601DateFormatter().string(from: Date())
    var appTables: [String] = []
    for app in apps.sorted(by: { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }) {
        let langs = app.languages.sorted()
        var langRows: [String] = []
        for lang in langs {
            let completion: String
            if lang == app.baseLanguage {
                let total = app.baseTotal
                completion = completionRatioText(translated: total, total: total)
            } else {
                let progress = app.progressByLanguage[lang] ?? LangProgress()
                completion = completionRatioText(translated: progress.translated, total: progress.total)
            }
            langRows.append(
                """
                <tr>
                  <td>\(htmlEscape(localizedLanguageLabel(lang)))</td>
                  <td>\(htmlEscape(completion))</td>
                </tr>
                """
            )
        }
        appTables.append(
            """
            <section class="app-block">
              <h2><a href="\(htmlEscape(app.pageFileName))">\(htmlEscape(app.appName))</a></h2>
              <div class="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Language</th>
                      <th>Completion</th>
                    </tr>
                  </thead>
                  <tbody>
                    \(langRows.joined(separator: "\n"))
                  </tbody>
                </table>
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
      <style>
        body { margin: 0; background: #f7f7f9; color: #1f2937; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
        .wrap { padding: 16px; }
        h1 { margin: 0 0 4px; font-size: 22px; }
        .meta { margin: 0 0 12px; color: #6b7280; font-size: 12px; }
        .app-block { margin: 0 0 16px; }
        h2 { margin: 0 0 8px; font-size: 16px; }
        .table-wrap { overflow: auto; border: 1px solid #e5e7eb; background: #fff; border-radius: 8px; }
        table { border-collapse: collapse; width: 100%; min-width: 720px; table-layout: fixed; }
        th, td { border-bottom: 1px solid #e5e7eb; border-right: 1px solid #e5e7eb; text-align: left; padding: 8px 10px; font-size: 12px; line-height: 1.5; }
        th { background: #f3f4f6; position: sticky; top: 0; }
        a { color: #2563eb; text-decoration: none; }
        a:hover { text-decoration: underline; }
      </style>
    </head>
    <body>
      <div class="wrap">
        <h1>My App i18n Preview</h1>
        <p class="meta">Generated at: \(htmlEscape(generatedAt)) · Apps: \(apps.count)</p>
        \(appTables.joined(separator: "\n"))
      </div>
    </body>
    </html>
    """
}

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
                tds += "\n<td class=\"\(cssClass)\">\(htmlEscape(value))</td>"
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

    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(htmlEscape(app.appName)) i18n Preview</title>
      <style>
        body { margin: 0; background: #f7f7f9; color: #1f2937; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
        .wrap { padding: 16px; }
        h1 { margin: 0 0 4px; font-size: 22px; }
        .meta { margin: 0 0 10px; color: #6b7280; font-size: 12px; }
        .chips { margin-bottom: 12px; display: flex; flex-wrap: wrap; gap: 6px; }
        .chip { display: inline-block; border: 1px solid #d1d5db; border-radius: 999px; padding: 2px 8px; font-size: 12px; background: #fff; color: #374151; }
        .toolbar { display: flex; justify-content: flex-start; align-items: center; margin-bottom: 10px; }
        .file-select { border: 1px solid #d1d5db; border-radius: 6px; background: #e6ecff; padding: 6px 8px; font-size: 12px; min-width: 360px; max-width: 100%; }
        .panel { display: none; }
        .panel.active { display: block; }
        h3 { margin: 0 0 8px; font-size: 14px; }
        .table-wrap { overflow: auto; border: 1px solid #e5e7eb; background: #fff; border-radius: 8px; }
        table { border-collapse: collapse; width: 100%; min-width: 820px; }
        th, td { border-bottom: 1px solid #e5e7eb; border-right: 1px solid #e5e7eb; text-align: left; vertical-align: top; padding: 8px 10px; font-size: 12px; line-height: 1.5; }
        th { position: sticky; top: 0; background: #f3f4f6; z-index: 1; }
        code { white-space: pre-wrap; word-break: break-all; }
        td { white-space: pre-wrap; word-break: break-word; }
        td.ok { background: #ecfdf5; color: #065f46; }
        td.todo { background: #fff7ed; color: #9a3412; }
        .back { display: inline-block; margin-bottom: 8px; color: #2563eb; text-decoration: none; }
        .back:hover { text-decoration: underline; }
        @media (max-width: 900px) {
          .toolbar { justify-content: stretch; }
          .file-select { min-width: 0; width: 100%; }
        }
      </style>
    </head>
    <body>
      <div class="wrap">
        <a class="back" href="index.html">← Back to index</a>
        <h1>\(htmlEscape(app.appName))</h1>
        <p class="meta">Generated at: \(htmlEscape(generatedAt)) · Files: \(app.files.count)</p>
        <div class="chips">
          \(summaryChips.joined(separator: "\n"))
        </div>
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
