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
                            "en": ["stringUnit": ["state": "new", "value": "Hello"]]
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
}
