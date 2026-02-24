import Foundation

struct Logger {
    static func info(_ message: String) { print(message) }
    static func warn(_ message: String) { fputs("Warning: \(message)\n", stderr) }
    static func error(_ message: String) { fputs("Error: \(message)\n", stderr) }
}

public enum AppError: Error {
    case message(String)
}
