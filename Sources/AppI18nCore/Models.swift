import Foundation

struct StringsFile {
    var entries: [String: String]
}

struct XCStringsFile {
    var sourceLanguage: String
    var version: String?
    var strings: [String: [String: Any]]
    var raw: [String: Any]
}
