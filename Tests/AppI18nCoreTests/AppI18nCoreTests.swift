import XCTest
import AppI18nCore
import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

final class AppI18nCoreTests: XCTestCase {
    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("appi18n-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = FileManager.default.currentDirectoryPath
        _ = FileManager.default.changeCurrentDirectoryPath(dir.path)
        defer {
            _ = FileManager.default.changeCurrentDirectoryPath(original)
            try? FileManager.default.removeItem(at: dir)
        }
        try body(dir)
    }

    func testAddLanguageCreatesStringsFile() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
            let xcFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let xcJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "Hello": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Hello"]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]
            let data = try JSONSerialization.data(withJSONObject: xcJSON, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: xcFile)

            try addLanguage(app: "menuist", lang: "fr")

            let target = dir
                .appendingPathComponent("i18n/lproj/menuist/fr.lproj/Localizable.strings")
            XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
            let content = try String(contentsOf: target, encoding: .utf8)
            XCTAssertTrue(content.contains("\"Hello\" = \"Hello\";"))
        }
    }

    func testToLprojPreservesExistingValues() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
            let xcFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let xcJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "Hello": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Hello"]],
                            "fr": ["stringUnit": ["state": "translated", "value": "Bonjour"]]
                        ]
                    ],
                    "Welcome": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Welcome"]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]
            let data = try JSONSerialization.data(withJSONObject: xcJSON, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: xcFile)

            let frDir = dir.appendingPathComponent("i18n/lproj/menuist/fr.lproj")
            try FileManager.default.createDirectory(at: frDir, withIntermediateDirectories: true)
            let existing = frDir.appendingPathComponent("Localizable.strings")
            try "\"Hello\" = \"Bonjour\";\n".write(to: existing, atomically: true, encoding: .utf8)

            try toLproj()

            let content = try String(contentsOf: existing, encoding: .utf8)
            XCTAssertTrue(content.contains("\"Hello\" = \"Bonjour\";"))
            XCTAssertTrue(content.contains("\"Welcome\" = \"Welcome\";"))
        }
    }

    func testToXCStringsUpdatesFromStrings() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
            let xcFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let xcJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "Hello": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Hello"]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]
            let data = try JSONSerialization.data(withJSONObject: xcJSON, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: xcFile)

            let frDir = dir.appendingPathComponent("i18n/lproj/menuist/fr.lproj")
            try FileManager.default.createDirectory(at: frDir, withIntermediateDirectories: true)
            let frStrings = frDir.appendingPathComponent("Localizable.strings")
            try "\"Hello\" = \"Bonjour\";\n".write(to: frStrings, atomically: true, encoding: .utf8)

            try toXCStrings()

            let updated = try Data(contentsOf: xcFile)
            let obj = try JSONSerialization.jsonObject(with: updated, options: [])
            guard let dict = obj as? [String: Any],
                  let strings = dict["strings"] as? [String: Any],
                  let entry = strings["Hello"] as? [String: Any],
                  let locs = entry["localizations"] as? [String: Any],
                  let fr = locs["fr"] as? [String: Any],
                  let unit = fr["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else {
                XCTFail("Updated JSON structure missing")
                return
            }
            XCTAssertEqual(value, "Bonjour")
        }
    }

    func testListLanguagesForApp() throws {
        try withTempDir { dir in
            let langDir = dir.appendingPathComponent("i18n/lproj/menuist/fr.lproj")
            try FileManager.default.createDirectory(at: langDir, withIntermediateDirectories: true)

            let langs = try getLanguages(app: "menuist")
            XCTAssertEqual(langs, ["fr"])
        }
    }

    func testPreviewHTMLGeneratesIndexAndAppPages() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
            let xcFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let xcJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "Hello": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Hello"]]
                        ]
                    ],
                    "Bye": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Bye"]],
                            "fr": ["stringUnit": ["state": "translated", "value": "Bye"]]
                        ]
                    ],
                    "ShouldBeHidden": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": ""]],
                            "fr": ["stringUnit": ["state": "translated", "value": "Doit être masqué"]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]
            let xcData = try JSONSerialization.data(withJSONObject: xcJSON, options: [.prettyPrinted, .sortedKeys])
            try xcData.write(to: xcFile)

            let enDir = dir.appendingPathComponent("i18n/lproj/menuist/en.lproj")
            let frDir = dir.appendingPathComponent("i18n/lproj/menuist/fr.lproj")
            try FileManager.default.createDirectory(at: enDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: frDir, withIntermediateDirectories: true)
            try "\"Hello\" = \"Hello\";\n\"Bye\" = \"Bye\";\n".write(
                to: enDir.appendingPathComponent("Localizable.strings"),
                atomically: true,
                encoding: .utf8
            )
            try "\"Hello\" = \"Bonjour\";\n\"Bye\" = \"Bye\";\n".write(
                to: frDir.appendingPathComponent("Localizable.strings"),
                atomically: true,
                encoding: .utf8
            )

            try previewHTML(apps: ["menuist"], outputPath: "i18n/preview")

            let indexOutput = dir.appendingPathComponent("i18n/preview/index.html")
            let appOutput = dir.appendingPathComponent("i18n/preview/menuist.html")

            XCTAssertTrue(FileManager.default.fileExists(atPath: indexOutput.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: appOutput.path))

            let indexHTML = try String(contentsOf: indexOutput, encoding: .utf8)
            XCTAssertTrue(indexHTML.contains("My App i18n Preview"))
            XCTAssertTrue(indexHTML.contains(">menuist</a>"))
            XCTAssertTrue(indexHTML.contains("app-block"))
            XCTAssertTrue(indexHTML.contains("<th>Language</th>"))
            XCTAssertTrue(indexHTML.contains("<th>Completion</th>"))
            XCTAssertFalse(indexHTML.contains("<th>App</th>"))
            XCTAssertTrue(indexHTML.contains("(en)"))
            XCTAssertTrue(indexHTML.contains("(fr)"))
            XCTAssertTrue(indexHTML.contains("100% (2/2)"))
            XCTAssertTrue(indexHTML.contains("100% (2/2)"))

            let appHTML = try String(contentsOf: appOutput, encoding: .utf8)
            XCTAssertTrue(appHTML.contains("menuist"))
            XCTAssertTrue(appHTML.contains("Localizable.strings"))
            XCTAssertTrue(appHTML.contains("file-select"))
            XCTAssertTrue(appHTML.contains("Default Value (en)"))
            XCTAssertFalse(appHTML.contains("Default Lang"))
            XCTAssertFalse(appHTML.contains("<th>en</th>"))
            XCTAssertFalse(appHTML.contains("ShouldBeHidden"))
            XCTAssertTrue(appHTML.contains("Bonjour"))
            XCTAssertTrue(appHTML.contains("activate("))
        }
    }
}
