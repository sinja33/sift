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

    static func run(_ script: String, language: Language = .javaScript, args: [String] = []) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", language.rawValue, "-e", script] + args
            let out = Pipe()
            let err = Pipe()
            process.standardOutput = out
            process.standardError = err
            try process.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let text = String(decoding: errData, as: UTF8.self)
                throw OsaError(message: text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
}
