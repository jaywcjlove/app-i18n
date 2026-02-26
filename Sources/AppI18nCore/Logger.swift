import Foundation

public struct Logger {
    public static func info(_ message: String) { print(message) }
    public static func warn(_ message: String) { fputs("\u{001B}[33mWarning:\u{001B}[0m \(message)\n", stderr) }
    public static func error(_ message: String) { fputs("\u{001B}[31mError:\u{001B}[0m \(message)\n", stderr) }
}

public enum AppError: Error {
    case message(String)
}
