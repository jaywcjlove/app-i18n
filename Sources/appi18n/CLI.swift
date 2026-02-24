import ArgumentParser
import AppI18nCore

let helpOverview = """
轻量级命令行工具，用于统一管理和优化多个 App 的国际化（i18n）流程。
"""

struct AppI18n: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appi18n",
        abstract: "App i18n",
        discussion: helpOverview,
        subcommands: [
            Extract.self,
            ToLproj.self,
            ToXCStrings.self,
            Status.self,
            Clean.self
        ]
    )
}

struct Extract: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "从 Xcode 项目中提取所有 .xcstrings 到 i18n/source"
    )

    @Argument(help: "Xcode 项目路径")
    var path: String

    mutating func run() throws {
        try extract(projectPath: path)
    }
}

struct ToLproj: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "to-lproj",
        abstract: "将 .xcstrings 转换为 .lproj 结构 (默认输出到 i18n/lproj)"
    )

    mutating func run() throws {
        try toLproj()
    }
}

struct ToXCStrings: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "to-xcstrings",
        abstract: "将 .lproj 更新到 .xcstrings (用于导入 Xcode)中"
    )

    mutating func run() throws {
        try toXCStrings()
    }
}

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "检查翻译状态 (missing / incomplete 语言)"
    )

    mutating func run() throws {
        try status()
    }
}

struct Clean: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "清理过时/空 .lproj 文件"
    )

    mutating func run() throws {
        try clean()
    }
}
