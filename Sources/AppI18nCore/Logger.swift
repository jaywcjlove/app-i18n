import Foundation

struct Logger {
    static func info(_ message: String) { print(message) }
    static func warn(_ message: String) { fputs("\u{001B}[33mWarning:\u{001B}[0m \(message)\n", stderr) }
    static func error(_ message: String) { fputs("\u{001B}[31mError:\u{001B}[0m \(message)\n", stderr) }
}

public enum AppError: Error {
    case message(String)
}
