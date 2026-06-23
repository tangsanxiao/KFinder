import Foundation

/// Minimal OpenAI-compatible chat client for session summaries. Works with any
/// `/chat/completions` endpoint (OpenAI, Azure-compatible, local servers,
/// proxies) — the user supplies base URL, model, and key in Settings.
enum SummaryLLMClient {
    enum ClientError: LocalizedError {
        case notConfigured
        case badResponse(Int, String)
        case noContent

        var errorDescription: String? {
            switch self {
            case .notConfigured: "未配置总结用的 LLM（请在设置中开启并填写 API 信息）。"
            case .badResponse(let code, let body):
                "LLM 请求失败（HTTP \(code)）：\(body.prefix(200))"
            case .noContent: "LLM 未返回内容。"
            }
        }
    }

    static let summaryInstruction = """
        你是会话归档助手。请用中文简要总结下面这段 AI 编码会话：\
        1) 主要目标/任务；2) 做了哪些关键决定或改动；3) 结论或未完成项。\
        300 字以内,直接给要点,不要逐条复述对话。
        """

    /// Builds the POST request for a chat-completions call. Pure (no network)
    /// so request shaping is unit-testable.
    static func makeRequest(config: SummaryLLMConfig, system: String, user: String) throws -> URLRequest {
        guard config.isUsable else { throw ClientError.notConfigured }
        let base = config.baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(
            in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else { throw ClientError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Bearer \(config.apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": 0.3,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Parses the assistant text out of a chat-completions JSON response. Pure
    /// and unit-testable.
    static func parseContent(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = obj["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func summarize(text: String, config: SummaryLLMConfig) async throws -> String {
        let request = try makeRequest(config: config, system: summaryInstruction, user: text)
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw ClientError.badResponse(code, String(decoding: data, as: UTF8.self))
        }
        guard let content = parseContent(data) else { throw ClientError.noContent }
        return content
    }
}
