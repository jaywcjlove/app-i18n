import Foundation

let fileManager = FileManager.default

func currentDirectoryURL() -> URL {
    URL(fileURLWithPath: fileManager.currentDirectoryPath)
}

func projectRootURL() -> URL {
    var url = currentDirectoryURL()
    while true {
        let source = url.appendingPathComponent("i18n/source")
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: source.path, isDirectory: &isDir), isDir.boolValue {
            return url
        }
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path {
            return currentDirectoryURL()
        }
        url = parent
    }
}

func i18nSourceURL() -> URL {
    projectRootURL().appendingPathComponent("i18n/source")
}

func i18nLprojURL() -> URL {
    projectRootURL().appendingPathComponent("i18n/lproj")
}

func ensureDirectory(_ url: URL) throws {
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
}

func listFiles(withExtension ext: String, under root: URL) -> [URL] {
    guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
        return []
    }
    var results: [URL] = []
    for case let fileURL as URL in enumerator {
        if fileURL.pathExtension.lowercased() == ext.lowercased() {
            results.append(fileURL)
        }
    }
    return results
}

func relativePath(from root: URL, to file: URL) -> String {
    let rootPath = root.standardizedFileURL.path
    let filePath = file.standardizedFileURL.path
    if filePath.hasPrefix(rootPath) {
        let idx = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        let sub = String(filePath[idx...])
        return sub.hasPrefix("/") ? String(sub.dropFirst()) : sub
    }
    return file.lastPathComponent
}

func copyFile(_ src: URL, to dst: URL) throws {
    try ensureDirectory(dst.deletingLastPathComponent())
    if fileManager.fileExists(atPath: dst.path) {
        try fileManager.removeItem(at: dst)
    }
    try fileManager.copyItem(at: src, to: dst)
}
