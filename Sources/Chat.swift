import Foundation

/// Chat with Claude through the Claude Code app the user is already logged
/// into, so messages use their Claude subscription instead of API credits.
/// Each message runs `claude -p` once; later messages resume the same session.
@MainActor
final class ChatModel: ObservableObject {
    struct Line: Identifiable, Equatable {
        var id = UUID()
        let fromUser: Bool
        let text: String
        var isError = false
        /// Set for replies that just arrived, so they type themselves out once.
        var isNew = false
    }

    static let systemPrompt = """
    You are \(PetModel.name), a small, friendly red panda who lives in the bottom-right corner \
    of the user's Mac screen as a desktop pet. Be warm and a little playful, but genuinely \
    helpful. Keep replies short: one to four sentences unless the user asks for more detail. \
    Reply in plain text without Markdown headings or tables, since you speak in a tiny chat window.
    """

    @Published var lines: [Line] = []
    @Published var isLoading = false

    var onReply: ((String) -> Void)?

    /// Claude Code session for this conversation; nil until the first reply.
    private var sessionID: String?

    /// Stop re-typing a reply once it has been shown.
    func markShown(_ id: UUID) {
        if let i = lines.firstIndex(where: { $0.id == id }), lines[i].isNew { lines[i].isNew = false }
    }

    func clear() {
        lines.removeAll()
        sessionID = nil
    }

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        lines.append(Line(fromUser: true, text: text))
        isLoading = true
        let session = sessionID
        Task {
            let result = await ClaudeCode.ask(text, resuming: session, systemPrompt: Self.systemPrompt)
            isLoading = false
            switch result {
            case .success(let reply):
                sessionID = reply.sessionID
                lines.append(Line(fromUser: false, text: reply.text, isNew: true))
                onReply?(reply.text)
            case .failure(let error):
                lines.append(Line(fromUser: false, text: error.message, isError: true))
            }
        }
    }
}

/// Runs the Claude Code command-line tool headlessly.
enum ClaudeCode {
    struct Reply { let text: String; let sessionID: String? }
    struct Failure: Error { let message: String }

    /// Where Claude Code usually lives. GUI apps don't get the shell's PATH,
    /// so check common install spots, then ask a login shell.
    static func locate() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude",
                          "/usr/local/bin/claude", "\(home)/.claude/local/claude"]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shell.arguments = ["-lc", "command -v claude"]
        let out = Pipe()
        shell.standardOutput = out
        shell.standardError = FileHandle.nullDevice
        guard (try? shell.run()) != nil else { return nil }
        shell.waitUntilExit()
        let path = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    static func ask(_ message: String, resuming session: String?, systemPrompt: String) async -> Result<Reply, Failure> {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: run(message, resuming: session, systemPrompt: systemPrompt))
            }
        }
    }

    private static func run(_ message: String, resuming session: String?, systemPrompt: String) -> Result<Reply, Failure> {
        guard let binary = locate() else {
            return .failure(Failure(message: "I couldn't find Claude Code on this Mac. Install it from claude.com/claude-code and log in, then try again."))
        }

        // Its own folder, so chats don't pick up any project's files or settings.
        let workDir = AppPaths.support.appendingPathComponent("chat", isDirectory: true)
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        var args = ["-p", "--output-format", "json",
                    "--tools", "",              // plain chat: no file, shell or web tools
                    "--strict-mcp-config",      // skip MCP servers for a fast start
                    "--effort", "low",          // short pet replies don't need deep thinking
                    "--system-prompt", systemPrompt]
        if let session { args += ["--resume", session] }

        // Make sure the subscription login is used: an API key in the
        // environment would take priority and bill API credits instead.
        var env = ProcessInfo.processInfo.environment
        for key in env.keys where key.hasPrefix("ANTHROPIC_") || key.hasPrefix("CLAUDE_CODE_") || key == "CLAUDECODE" {
            env.removeValue(forKey: key)
        }
        env["PATH"] = (env["PATH"].map { $0 + ":" } ?? "") + "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        process.currentDirectoryURL = workDir
        process.environment = env
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do { try process.run() } catch {
            return .failure(Failure(message: "Couldn't start Claude Code: \(error.localizedDescription)"))
        }
        // The message goes in on stdin so text starting with "-" is never read as an option.
        stdin.fileHandleForWriting.write(Data(message.utf8))
        try? stdin.fileHandleForWriting.close()

        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 180, execute: timeout)

        // Read both pipes fully before waiting, so a large reply can't block the process.
        var errData = Data()
        let errRead = DispatchWorkItem { errData = stderr.fileHandleForReading.readDataToEndOfFile() }
        DispatchQueue.global().async(execute: errRead)
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        errRead.wait()
        process.waitUntilExit()
        timeout.cancel()

        if process.terminationReason == .uncaughtSignal {
            return .failure(Failure(message: "Claude took too long to answer. Try again in a moment."))
        }
        guard let json = (try? JSONSerialization.jsonObject(with: outData)) as? [String: Any] else {
            let err = String(data: errData, encoding: .utf8)?
                .split(separator: "\n").first.map(String.init) ?? "unknown error"
            return .failure(Failure(message: "Claude Code had a problem: \(err)"))
        }
        let text = (json["result"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if json["is_error"] as? Bool == true {
            let lower = text.lowercased()
            if lower.contains("login") || lower.contains("log in") || lower.contains("api key") {
                return .failure(Failure(message: "Claude Code isn't logged in. Open Terminal, run `claude`, and log in with your Claude account."))
            }
            return .failure(Failure(message: text.isEmpty ? "Claude Code returned an error." : text))
        }
        return .success(Reply(text: text.isEmpty ? "…" : text, sessionID: json["session_id"] as? String))
    }
}
