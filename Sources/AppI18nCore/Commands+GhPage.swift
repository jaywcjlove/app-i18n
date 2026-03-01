import Foundation

/// Result of a shell command invocation used by ghpage publishing flow.
private struct ShellResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

/// Execute a git command in a specific working directory.
/// The command is executed as `/usr/bin/env git ...` for portability.
private func runGit(_ args: [String], at directory: URL) -> ShellResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + args
    process.currentDirectoryURL = directory

    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe

    do {
        try process.run()
    } catch {
        return ShellResult(status: -1, stdout: "", stderr: error.localizedDescription)
    }
    process.waitUntilExit()

    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return ShellResult(
        status: process.terminationStatus,
        stdout: out.trimmingCharacters(in: .whitespacesAndNewlines),
        stderr: err.trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

/// Remove everything under the target worktree except `.git`.
/// This guarantees the published branch contains only the selected source content.
private func removeAllContents(in directory: URL) throws {
    let children = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
    for item in children {
        if item.lastPathComponent == ".git" { continue }
        try fileManager.removeItem(at: item)
    }
}

/// Copy all direct children from source directory to destination directory.
/// Hidden files are included intentionally (e.g. `.nojekyll`).
private func copyDirectoryContents(from source: URL, to destination: URL) throws {
    let children = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: [])
    for item in children {
        let target = destination.appendingPathComponent(item.lastPathComponent)
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        try fileManager.copyItem(at: item, to: target)
    }
}

/// Publish static files to a pages branch by committing source directory contents.
///
/// Behavior summary:
/// 1. Validate source folder and git availability
/// 2. Create temporary worktree for target branch (or create branch if missing)
/// 3. Replace branch content with source folder content
/// 4. Commit changes when there are staged diffs
///
/// Notes:
/// - This function only creates a local commit; it does not push to remote.
/// - Current working branch is not switched because worktree is used.
public func ghpage(branch: String = "gh-pages", sourcePath: String = ".html", commitMessage: String? = nil) throws {
    let root = projectRootURL()
    let sourceURL = URL(fileURLWithPath: sourcePath, relativeTo: root).standardizedFileURL

    var isDir: ObjCBool = false
    guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDir), isDir.boolValue else {
        throw AppError.message("Source folder not found: \(sourceURL.path)")
    }

    let gitVersion = runGit(["--version"], at: root)
    guard gitVersion.status == 0 else {
        throw AppError.message("git command not found or unavailable.")
    }

    // Detect local branch existence; create it if absent.
    let branchExists = runGit(["rev-parse", "--verify", "refs/heads/\(branch)"], at: root).status == 0
    let tempWorktree = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("appi18n-ghpage-\(UUID().uuidString)")
    try ensureDirectory(tempWorktree)

    let addWorktreeArgs: [String] = branchExists
        ? ["worktree", "add", tempWorktree.path, branch]
        : ["worktree", "add", "-b", branch, tempWorktree.path]
    let addResult = runGit(addWorktreeArgs, at: root)
    guard addResult.status == 0 else {
        try? fileManager.removeItem(at: tempWorktree)
        throw AppError.message("Failed to prepare worktree: \(addResult.stderr)")
    }

    // Always cleanup temporary worktree even if publishing fails.
    defer {
        _ = runGit(["worktree", "remove", "--force", tempWorktree.path], at: root)
        try? fileManager.removeItem(at: tempWorktree)
    }

    try removeAllContents(in: tempWorktree)
    try copyDirectoryContents(from: sourceURL, to: tempWorktree)

    let addFiles = runGit(["add", "-A"], at: tempWorktree)
    guard addFiles.status == 0 else {
        throw AppError.message("Failed to stage files: \(addFiles.stderr)")
    }

    let status = runGit(["status", "--porcelain"], at: tempWorktree)
    if status.status != 0 {
        throw AppError.message("Failed to inspect git status: \(status.stderr)")
    }
    if status.stdout.isEmpty {
        Logger.info("No changes to commit on branch \(branch).")
        return
    }

    let message = (commitMessage?.isEmpty == false) ? commitMessage! : "chore: publish \(sourceURL.lastPathComponent)"
    let commit = runGit(["commit", "-m", message], at: tempWorktree)
    guard commit.status == 0 else {
        throw AppError.message("Failed to commit changes: \(commit.stderr)")
    }

    let hash = runGit(["rev-parse", "--short", "HEAD"], at: tempWorktree).stdout
    Logger.info("Committed \(sourceURL.path) to branch \(branch)\(hash.isEmpty ? "" : " (\(hash))")")
}
