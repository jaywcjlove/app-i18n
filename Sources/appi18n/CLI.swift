import ArgumentParser
import AppI18nCore

let helpOverview = """
Lightweight CLI tool for managing and optimizing multi-app localization (i18n).
"""

let helpExamples = """
Examples:
  appi18n extract /path/to/YourApp
  appi18n to-lproj
  appi18n add-lang menuist fr
  appi18n list-langs menuist
  appi18n langs
  appi18n to-xcstrings
  appi18n status
  appi18n clean
"""

struct AppI18n: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appi18n",
        abstract: "App i18n",
        discussion: helpOverview + "\n\n" + helpExamples,
        subcommands: [
            Extract.self,
            ToLproj.self,
            AddLang.self,
            ListLangs.self,
            Langs.self,
            ToXCStrings.self,
            Status.self,
            Clean.self
        ]
    )
}

struct Extract: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract all .xcstrings from an Xcode project into i18n/source"
    )

    @Argument(help: "Path to the Xcode project")
    var path: String

    mutating func run() throws {
        try extract(projectPath: path)
    }
}

struct ToLproj: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "to-lproj",
        abstract: "Convert .xcstrings to .lproj (default output to i18n/lproj)"
    )

    mutating func run() throws {
        try toLproj()
    }
}

struct AddLang: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add-lang",
        abstract: "Add a new language to .lproj"
    )

    @Argument(help: "App directory name under i18n/source")
    var app: String

    @Argument(help: "Language code, e.g. en, zh-Hans, fr")
    var lang: String

    mutating func run() throws {
        if app.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError("App name cannot be empty.")
        }
        if lang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError("Language code cannot be empty.")
        }
        try addLanguage(app: app, lang: lang)
    }
}

struct ListLangs: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-langs",
        abstract: "List existing languages for an app"
    )

    @Argument(help: "App directory name under i18n/lproj")
    var app: String
    mutating func run() throws {
        if app.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError("App name cannot be empty.")
        }
        try listLanguages(app: app)
    }
}

struct Langs: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "langs",
        abstract: "List supported language codes for add-lang"
    )

    @Flag(name: .long, help: "Print all system-provided language/region identifiers")
    var all: Bool = false

    mutating func run() throws {
        listSupportedLanguages(all: all)
    }
}

struct ToXCStrings: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "to-xcstrings",
        abstract: "Update .xcstrings from .lproj (for importing to Xcode)"
    )

    mutating func run() throws {
        try toXCStrings()
    }
}

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Check translation status (missing / incomplete languages)"
    )

    mutating func run() throws {
        try status()
    }
}

struct Clean: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean outdated/empty .lproj files"
    )

    mutating func run() throws {
        try clean()
    }
}
