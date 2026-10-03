import Foundation

/// Chat with Claude over the Messages API using plain HTTP (there is no
/// official Swift SDK). The conversation is append-only: assistant turns are
/// stored exactly as returned so they can be sent back unchanged.
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

    static let model = "claude-opus-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let systemPrompt = """
    You are \(PetModel.name), a small, friendly desktop pet who lives in the bottom-right corner \
    of the user's Mac screen. Be warm and a little playful, but genuinely helpful. Keep replies \
    short: one to four sentences unless the user asks for more detail. Reply in plain text \
    without Markdown headings or tables, since you speak through a tiny chat bubble.
    """

    @Published var lines: [Line] = []
    @Published var isLoading = false
    @Published var apiKey: String = APIKeyStore.load() ?? ""

    var onReply: ((String) -> Void)?

    /// Raw API messages (user strings and assistant content arrays).
    private var history: [[String: Any]] = []

    var hasKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmed
        APIKeyStore.save(trimmed)
    }

    func forgetKey() {
        apiKey = ""
        APIKeyStore.save(nil)
    }

    /// Stop re-typing a reply once it has been shown.
    func markShown(_ id: UUID) {
        if let i = lines.firstIndex(where: { $0.id == id }), lines[i].isNew { lines[i].isNew = false }
    }

    func clear() {
        lines.removeAll()
        history.removeAll()
    }

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading, hasKey else { return }
        lines.append(Line(fromUser: true, text: text))
        history.append(["role": "user", "content": text])
        isLoading = true
        let messages = history
        let key = apiKey
        Task {
            let result = await Self.request(messages: messages, apiKey: key)
            isLoading = false
            switch result {
            case .success(let reply):
                history.append(["role": "assistant", "content": reply.content])
                lines.append(Line(fromUser: false, text: reply.text, isNew: true))
                onReply?(reply.text)
            case .failure(let error):
                // Drop the unanswered user turn so the next send stays valid.
                history.removeLast()
                lines.append(Line(fromUser: false, text: error.message, isError: true))
            }
        }
    }

    struct Reply { let text: String; let content: Any }
    struct ChatError: Error { let message: String }

    static func request(messages: [[String: Any]], apiKey: String) async -> Result<Reply, ChatError> {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": systemPrompt,
            "messages": messages,
            // Short pet replies don't need deep reasoning; low effort keeps them fast and cheap.
            "output_config": ["effort": "low"],
            // If a safety classifier declines, let the API retry on its recommended fallback model.
            "fallbacks": "default",
        ]
        var req = URLRequest(url: endpoint, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            guard status == 200 else {
                let apiMsg = (json["error"] as? [String: Any])?["message"] as? String
                switch status {
                case 401: return .failure(ChatError(message: "That API key didn't work. Check it in the chat settings."))
                case 429: return .failure(ChatError(message: "I'm being rate limited. Try again in a moment."))
                case 500...599: return .failure(ChatError(message: "Claude's servers are having a moment. Try again soon."))
                default: return .failure(ChatError(message: "Error \(status): \(apiMsg ?? "unknown error")"))
                }
            }
            if json["stop_reason"] as? String == "refusal" {
                return .failure(ChatError(message: "I can't help with that one."))
            }
            let content = json["content"] as? [[String: Any]] ?? []
            let text = content.filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(Reply(text: text.isEmpty ? "…" : text, content: content))
        } catch {
            return .failure(ChatError(message: "Couldn't reach Claude: \(error.localizedDescription)"))
        }
    }
}

/// Stores the API key in a private file (mode 600) in Application Support.
/// Falls back to the ANTHROPIC_API_KEY environment variable when launched from a shell.
enum APIKeyStore {
    static var fileURL: URL { AppPaths.support.appendingPathComponent("api_key") }

    static func load() -> String? {
        if let saved = try? String(contentsOf: fileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !saved.isEmpty {
            return saved
        }
        return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
    }

    static func save(_ key: String?) {
        guard let key, !key.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        FileManager.default.createFile(atPath: fileURL.path, contents: Data(key.utf8),
                                       attributes: [.posixPermissions: 0o600])
    }
}
