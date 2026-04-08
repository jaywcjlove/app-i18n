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

    func testExtractCopiesAppIconToLogoPNG() throws {
        try withTempDir { dir in
            let projectRoot = dir.appendingPathComponent("YourApp")
            let sourceRoot = projectRoot.appendingPathComponent("Sources")
            let xcassets = sourceRoot.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
            try FileManager.default.createDirectory(at: xcassets, withIntermediateDirectories: true)

            let xcFile = projectRoot.appendingPathComponent("Localizable.xcstrings")
            let xcJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [:],
                "version": "1.0"
            ]
            try JSONSerialization.data(withJSONObject: xcJSON, options: [.prettyPrinted, .sortedKeys]).write(to: xcFile)

            let contentsJSON: [String: Any] = [
                "images": [
                    [
                        "filename": "icon-128.png",
                        "idiom": "mac",
                        "scale": "1x",
                        "size": "128x128"
                    ]
                ],
                "info": [
                    "author": "xcode",
                    "version": 1
                ]
            ]
            try JSONSerialization.data(withJSONObject: contentsJSON, options: [.prettyPrinted, .sortedKeys]).write(
                to: xcassets.appendingPathComponent("Contents.json")
            )
            let pngData = Data([0x89, 0x50, 0x4E, 0x47])
            try pngData.write(to: xcassets.appendingPathComponent("icon-128.png"))

            try extract(projectPath: projectRoot.path)

            let logo = dir.appendingPathComponent("i18n/source/yourapp/logo.png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: logo.path))
            XCTAssertEqual(try Data(contentsOf: logo), pngData)
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

    func testToLprojRemovesStaleKeysAndFiles() throws {
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
                    ]
                ],
                "version": "1.0"
            ]
            let data = try JSONSerialization.data(withJSONObject: xcJSON, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: xcFile)

            let frDir = dir.appendingPathComponent("i18n/lproj/menuist/fr.lproj")
            try FileManager.default.createDirectory(at: frDir, withIntermediateDirectories: true)

            let localizable = frDir.appendingPathComponent("Localizable.strings")
            try """
            "Hello" = "Bonjour";
            "OldKey" = "Ancienne valeur";
            """.write(to: localizable, atomically: true, encoding: .utf8)

            let obsolete = frDir.appendingPathComponent("Obsolete.strings")
            try "\"Legacy\" = \"Legacy\";\n".write(to: obsolete, atomically: true, encoding: .utf8)

            try toLproj()

            let content = try String(contentsOf: localizable, encoding: .utf8)
            XCTAssertTrue(content.contains("\"Hello\" = \"Bonjour\";"))
            XCTAssertFalse(content.contains("\"OldKey\" = \"Ancienne valeur\";"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: obsolete.path))
        }
    }

    func testToLprojSkipsEmptyPlaceholderEntry() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
            let xcFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let xcJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": ""]],
                            "fr": ["stringUnit": ["state": "translated", "value": ""]]
                        ]
                    ],
                    "Hello": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Hello"]],
                            "fr": ["stringUnit": ["state": "translated", "value": "Bonjour"]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]
            let data = try JSONSerialization.data(withJSONObject: xcJSON, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: xcFile)

            try toLproj()

            let target = dir.appendingPathComponent("i18n/lproj/menuist/fr.lproj/Localizable.strings")
            let content = try String(contentsOf: target, encoding: .utf8)
            XCTAssertTrue(content.contains("\"Hello\" = \"Bonjour\";"))
            XCTAssertFalse(content.contains("\"\" = \"\";"))
        }
    }

    func testToLprojUsesAppLevelLanguagesForAllFiles() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot.appendingPathComponent("DependencyKit"), withIntermediateDirectories: true)

            let appXCFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let dependencyXCFile = sourceRoot.appendingPathComponent("DependencyKit/Localizable.xcstrings")

            let appXCJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "MainHello": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Hello"]],
                            "fr": ["stringUnit": ["state": "translated", "value": "Bonjour"]],
                            "de": ["stringUnit": ["state": "translated", "value": "Hallo"]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]
            let dependencyXCJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "PackageHello": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": "Package Hello"]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]

            try JSONSerialization.data(withJSONObject: appXCJSON, options: [.prettyPrinted, .sortedKeys]).write(to: appXCFile)
            try JSONSerialization.data(withJSONObject: dependencyXCJSON, options: [.prettyPrinted, .sortedKeys]).write(to: dependencyXCFile)

            try toLproj()

            let dependencyFR = dir.appendingPathComponent("i18n/lproj/menuist/fr.lproj/DependencyKit/Localizable.strings")
            let dependencyDE = dir.appendingPathComponent("i18n/lproj/menuist/de.lproj/DependencyKit/Localizable.strings")

            XCTAssertTrue(FileManager.default.fileExists(atPath: dependencyFR.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: dependencyDE.path))

            let frContent = try String(contentsOf: dependencyFR, encoding: .utf8)
            let deContent = try String(contentsOf: dependencyDE, encoding: .utf8)
            XCTAssertTrue(frContent.contains("\"PackageHello\" = \"Package Hello\";"))
            XCTAssertTrue(deContent.contains("\"PackageHello\" = \"Package Hello\";"))
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

    func testToXCStringsMarksEmptyTranslationAsTranslated() throws {
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
            try "\"Hello\" = \"\";\n".write(to: frStrings, atomically: true, encoding: .utf8)

            try toXCStrings()

            let updated = try Data(contentsOf: xcFile)
            let obj = try JSONSerialization.jsonObject(with: updated, options: [])
            guard let dict = obj as? [String: Any],
                  let strings = dict["strings"] as? [String: Any],
                  let entry = strings["Hello"] as? [String: Any],
                  let locs = entry["localizations"] as? [String: Any],
                  let fr = locs["fr"] as? [String: Any],
                  let unit = fr["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String,
                  let state = unit["state"] as? String else {
                XCTFail("Updated JSON structure missing")
                return
            }
            XCTAssertEqual(value, "")
            XCTAssertEqual(state, "translated")
        }
    }

    func testToXCStringsMarksAllEmptyLocalizationsAsTranslated() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
            let xcFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let xcJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "Hello": [
                        "localizations": [
                            "en": ["stringUnit": ["state": "new", "value": ""]],
                            "fr": ["stringUnit": ["state": "new", "value": ""]],
                            "de": ["stringUnit": ["state": "new", "value": "Hallo"]]
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
            try "\"Hello\" = \"\";\n".write(to: frStrings, atomically: true, encoding: .utf8)

            try toXCStrings()

            let updated = try Data(contentsOf: xcFile)
            let obj = try JSONSerialization.jsonObject(with: updated, options: [])
            guard let dict = obj as? [String: Any],
                  let strings = dict["strings"] as? [String: Any],
                  let entry = strings["Hello"] as? [String: Any],
                  let locs = entry["localizations"] as? [String: Any],
                  let en = locs["en"] as? [String: Any],
                  let fr = locs["fr"] as? [String: Any],
                  let enUnit = en["stringUnit"] as? [String: Any],
                  let frUnit = fr["stringUnit"] as? [String: Any],
                  let enState = enUnit["state"] as? String,
                  let frState = frUnit["state"] as? String else {
                XCTFail("Updated JSON structure missing")
                return
            }

            XCTAssertEqual(enState, "translated")
            XCTAssertEqual(frState, "translated")
        }
    }

    func testToXCStringsMarksEmptyLocalizationsTranslatedWithoutMatchingLprojFile() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
            let touchedXCFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let untouchedXCFile = sourceRoot.appendingPathComponent("InfoPlist.xcstrings")

            let touchedJSON: [String: Any] = [
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
            let untouchedJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "": [
                        "localizations": [
                            "ja": ["stringUnit": ["state": "new", "value": ""]],
                            "ko": ["stringUnit": ["state": "new", "value": ""]],
                            "zh-Hans": ["stringUnit": ["state": "new", "value": ""]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]
            try JSONSerialization.data(withJSONObject: touchedJSON, options: [.prettyPrinted, .sortedKeys]).write(to: touchedXCFile)
            try JSONSerialization.data(withJSONObject: untouchedJSON, options: [.prettyPrinted, .sortedKeys]).write(to: untouchedXCFile)

            let frDir = dir.appendingPathComponent("i18n/lproj/menuist/fr.lproj")
            try FileManager.default.createDirectory(at: frDir, withIntermediateDirectories: true)
            let frStrings = frDir.appendingPathComponent("Localizable.strings")
            try "\"Hello\" = \"Bonjour\";\n".write(to: frStrings, atomically: true, encoding: .utf8)

            try toXCStrings()

            let updated = try Data(contentsOf: untouchedXCFile)
            let obj = try JSONSerialization.jsonObject(with: updated, options: [])
            guard let dict = obj as? [String: Any],
                  let strings = dict["strings"] as? [String: Any],
                  let entry = strings[""] as? [String: Any],
                  let locs = entry["localizations"] as? [String: Any] else {
                XCTFail("Updated JSON structure missing")
                return
            }

            for language in ["ja", "ko", "zh-Hans"] {
                let lang = locs[language] as? [String: Any]
                let unit = lang?["stringUnit"] as? [String: Any]
                let state = unit?["state"] as? String
                XCTAssertEqual(state, "translated")
            }
        }
    }

    func testToXCStringsAddsMissingLanguagesForEmptyKey() throws {
        try withTempDir { dir in
            let sourceRoot = dir.appendingPathComponent("i18n/source/menuist")
            try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
            let xcFile = sourceRoot.appendingPathComponent("Localizable.xcstrings")
            let xcJSON: [String: Any] = [
                "sourceLanguage": "en",
                "strings": [
                    "": [
                        "localizations": [
                            "ja": ["stringUnit": ["state": "translated", "value": ""]]
                        ]
                    ]
                ],
                "version": "1.0"
            ]
            try JSONSerialization.data(withJSONObject: xcJSON, options: [.prettyPrinted, .sortedKeys]).write(to: xcFile)

            for lang in ["de", "fr", "ja", "zh-Hant"] {
                let dirURL = dir.appendingPathComponent("i18n/lproj/menuist/\(lang).lproj")
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                try "\"Hello\" = \"Hello\";\n".write(
                    to: dirURL.appendingPathComponent("Localizable.strings"),
                    atomically: true,
                    encoding: .utf8
                )
            }

            try toXCStrings()

            let updated = try Data(contentsOf: xcFile)
            let obj = try JSONSerialization.jsonObject(with: updated, options: [])
            guard let dict = obj as? [String: Any],
                  let strings = dict["strings"] as? [String: Any],
                  let entry = strings[""] as? [String: Any],
                  let locs = entry["localizations"] as? [String: Any] else {
                XCTFail("Updated JSON structure missing")
                return
            }

            for language in ["de", "fr", "ja", "zh-Hant"] {
                let lang = locs[language] as? [String: Any]
                let unit = lang?["stringUnit"] as? [String: Any]
                XCTAssertEqual(unit?["value"] as? String, "")
                XCTAssertEqual(unit?["state"] as? String, "translated")
            }
            XCTAssertNil(locs["en"])
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
            try Data([0x89, 0x50, 0x4E, 0x47]).write(to: sourceRoot.appendingPathComponent("logo.png"))

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
            let copiedLogo = dir.appendingPathComponent("i18n/preview/assets/logos/menuist.png")
            let cssOutput = dir.appendingPathComponent("i18n/preview/preview.css")

            XCTAssertTrue(FileManager.default.fileExists(atPath: indexOutput.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: appOutput.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: copiedLogo.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: cssOutput.path))

            let indexHTML = try String(contentsOf: indexOutput, encoding: .utf8)
            XCTAssertTrue(indexHTML.contains("My App i18n Preview"))
            XCTAssertTrue(indexHTML.contains("href=\"preview.css\""))
            XCTAssertTrue(indexHTML.contains(">menuist</a>"))
            XCTAssertTrue(indexHTML.contains("apps-grid"))
            XCTAssertTrue(indexHTML.contains("app-logo"))
            XCTAssertTrue(indexHTML.contains("assets/logos/menuist.png"))
            XCTAssertTrue(indexHTML.contains("language-list"))
            XCTAssertTrue(indexHTML.contains("progress-track"))
            XCTAssertFalse(indexHTML.contains("<th>Language</th>"))
            XCTAssertTrue(indexHTML.contains("(en)"))
            XCTAssertTrue(indexHTML.contains("(fr)"))
            XCTAssertTrue(indexHTML.contains("100% (2/2)"))
            XCTAssertTrue(indexHTML.contains("100% (2/2)"))

            let appHTML = try String(contentsOf: appOutput, encoding: .utf8)
            XCTAssertTrue(appHTML.contains("menuist"))
            XCTAssertTrue(appHTML.contains("href=\"preview.css\""))
            XCTAssertTrue(appHTML.contains("assets/logos/menuist.png"))
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
