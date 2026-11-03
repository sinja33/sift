import Foundation

struct OsaError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Runs AppleScript or JavaScript for Automation through `osascript`, off the main thread.
/// Values reach the script's `run` handler as argv, so nothing is spliced into script text.
enum Osa {
    enum Language: String {
        case appleScript = "AppleScript"
        case javaScript = "JavaScript"
    }

    /// Holds the running process so cancelling the task can stop it.
    private final class Running: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false

        func set(_ process: Process) {
            lock.lock(); defer { lock.unlock() }
            self.process = process
            if cancelled { process.terminate() }
        }

        func cancel() {
            lock.lock(); defer { lock.unlock() }
            cancelled = true
            process?.terminate()
        }
    }

    /// Cancelling the calling task stops the script. A song that was swiped away should not keep waiting to play.
    static func run(_ script: String, language: Language = .javaScript, args: [String] = []) async throws -> String {
        let running = Running()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-l", language.rawValue, "-e", script] + args
                let out = Pipe()
                let err = Pipe()
                process.standardOutput = out
                process.standardError = err
                try process.run()
                running.set(process)
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    let text = String(decoding: errData, as: UTF8.self)
                    throw OsaError(message: text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            }.value
        } onCancel: {
            running.cancel()
        }
    }
}
