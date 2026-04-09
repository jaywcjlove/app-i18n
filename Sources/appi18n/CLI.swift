import ArgumentParser
import AppI18nCore

let helpOverview = """
Lightweight CLI tool for managing and optimizing multi-app localization (i18n).
"""

let helpExamples = """
Examples:
  appi18n extract /path/to/YourApp
  appi18n to-lproj
  appi18n langs menuist,scap fr
  appi18n langs menuist
  appi18n langs
  appi18n langs --all
  appi18n to-xcstrings
  appi18n status
  appi18n preview
  appi18n ghpage
  appi18n clean
"""

struct AppI18n: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appi18n",
        abstract: "App i18n",
        discussion: helpOverview + "\n\n" + helpExamples,
        version: "1.5.0",
        subcommands: [
            Extract.self,
            ToLproj.self,
            Langs.self,
            ToXCStrings.self,
            Status.self,
            Preview.self,
            GhPage.self,
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

struct Langs: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "langs",
        abstract: "List app languages or add a language to app(s)"
    )

    @Argument(help: "Comma-separated app names (under i18n/source and i18n/lproj). Omit to use --all.")
    var apps: String?

    @Argument(help: "Language code to add (optional). If omitted, list existing languages.")
    var lang: String?

    @Flag(name: .long, help: "Also print all system-provided language/region identifiers")
    var all: Bool = false

    mutating func run() throws {
        guard let apps else {
            if all {
                Logger.info("")
                Logger.info("Supported language codes:")
                listSupportedLanguages(all: true)
                return
            }
            listSupportedLanguages(all: false)
            return
        }

        let appList = apps
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if appList.isEmpty {
            throw ValidationError("App name cannot be empty.")
        }
        if let lang {
            if lang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationError("Language code cannot be empty.")
            }
            try addLanguage(apps: appList, lang: lang)
        } else {
            try listLanguages(apps: appList)
        }
        if all {
            Logger.info("")
            Logger.info("Supported language codes:")
            listSupportedLanguages(all: true)
        }
    }
}

struct ToXCStrings: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "to-xcstrings",
        abstract: "Update .xcstrings from .lproj (for importing to Xcode)"
    )

    @Flag(inversion: .prefixedNo, help: "Skip updates when .strings value equals the .xcstrings default value")
    var skipDefaultValue: Bool = true

    mutating func run() throws {
        try toXCStrings(skipDefaultValue: skipDefaultValue)
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

struct Preview: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview",
        abstract: "Generate an HTML preview for translations"
    )

    @Argument(help: "Comma-separated app names under i18n/lproj. Omit to include all apps.")
    var apps: String?

    @Option(name: .shortAndLong, help: "Output directory for index.html and app detail pages")
    var output: String = ".html"

    mutating func run() throws {
        let appList = apps?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let outputPath = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if outputPath.isEmpty {
            throw ValidationError("Output path cannot be empty.")
        }
        try previewHTML(apps: appList, outputPath: outputPath)
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

struct GhPage: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ghpage",
        abstract: "Commit generated HTML files to a branch (default: gh-pages)"
    )

    @Option(name: [.short, .long], help: "Target branch name")
    var branch: String = "gh-pages"

    @Option(name: [.short, .long], help: "Source folder containing generated HTML files")
    var source: String = ".html"

    @Option(name: .long, help: "Commit message")
    var message: String?

    mutating func run() throws {
        let targetBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourcePath = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let commitMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if targetBranch.isEmpty {
            throw ValidationError("Branch name cannot be empty.")
        }
        if sourcePath.isEmpty {
            throw ValidationError("Source folder cannot be empty.")
        }
        try ghpage(branch: targetBranch, sourcePath: sourcePath, commitMessage: commitMessage)
    }
}
