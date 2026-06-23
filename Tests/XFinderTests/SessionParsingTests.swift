import Foundation
import Testing

@testable import XFinder

@Test func parsesClaudeUserAndAssistantLines() {
    let userLine = #"{"type":"user","cwd":"/p","message":{"content":"hello there"}}"#
    let asstLine = #"{"type":"assistant","message":{"content":[{"type":"text","text":"hi back"}]}}"#

    let u = SessionParsing.message(fromLine: userLine)
    #expect(u?.role == .user)
    #expect(u?.text == "hello there")

    let a = SessionParsing.message(fromLine: asstLine)
    #expect(a?.role == .assistant)
    #expect(a?.text == "hi back")

    #expect(SessionParsing.cwd(fromLine: userLine) == "/p")
}

@Test func parsesCodexResponseItemLines() {
    let line =
        #"{"timestamp":"t","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"do the thing"}]}}"#
    let m = SessionParsing.message(fromLine: line)
    #expect(m?.role == .user)
    #expect(m?.text == "do the thing")

    let meta = #"{"type":"session_meta","payload":{"cwd":"/work/proj","id":"x"}}"#
    #expect(SessionParsing.cwd(fromLine: meta) == "/work/proj")
}

@Test func skipsToolAndNonMessageLines() {
    #expect(SessionParsing.message(fromLine: #"{"type":"summary","summary":"x"}"#) == nil)
    #expect(SessionParsing.message(fromLine: #"{"payload":{"type":"function_call","call_id":"1"}}"#) == nil)
    #expect(SessionParsing.message(fromLine: "not json") == nil)
}

@Test func detectsPreambleTitles() {
    #expect(SessionParsing.isPreamble("# AGENTS.md instructions for /x"))
    #expect(SessionParsing.isPreamble("<system-reminder>do x</system-reminder>"))
    #expect(SessionParsing.isPreamble("# Files mentioned by the user:\n## clip.png"))
    #expect(SessionParsing.isPreamble("<INSTRUCTIONS>\n全局协作纪律"))
    #expect(!SessionParsing.isPreamble("帮我设计一个搜索后台"))
}

@Test func stripsPreambleTurnsKeepingRealConversation() {
    let messages = [
        SessionMessage(id: 0, role: .user, text: "# AGENTS.md instructions for /x"),
        SessionMessage(id: 1, role: .user, text: "# Files mentioned by the user:\n## a.png"),
        SessionMessage(id: 2, role: .user, text: "为啥网络访问不了"),
        SessionMessage(id: 3, role: .assistant, text: "因为…"),
    ]
    let kept = SessionParsing.stripPreamble(messages)
    #expect(kept.map(\.text) == ["为啥网络访问不了", "因为…"])
}

@Test func estimatesTokens() {
    #expect(SessionParsing.estimateTokens(chars: 400) == 100)
    #expect(SessionParsing.estimateTokens(bytes: 4096) == 1024)
}

@Test func llmRequestBuildsOpenAICompatibleCall() throws {
    var config = SummaryLLMConfig()
    config.enabled = true
    config.apiKey = "sk-test"
    config.baseURL = "https://api.example.com/v1/"  // trailing slash tolerated
    config.model = "gpt-4o-mini"

    let request = try SummaryLLMClient.makeRequest(config: config, system: "sys", user: "hi")
    #expect(request.url?.absoluteString == "https://api.example.com/v1/chat/completions")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")

    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["model"] as? String == "gpt-4o-mini")
    let messages = try #require(json["messages"] as? [[String: String]])
    #expect(messages.count == 2)
    #expect(messages[0]["role"] == "system")
}

@Test func llmRequestRequiresConfig() {
    var config = SummaryLLMConfig()  // disabled, no key
    #expect(throws: (any Error).self) {
        _ = try SummaryLLMClient.makeRequest(config: config, system: "s", user: "u")
    }
    config.enabled = true  // still no key
    #expect(throws: (any Error).self) {
        _ = try SummaryLLMClient.makeRequest(config: config, system: "s", user: "u")
    }
}

@Test func llmParsesChoiceContent() throws {
    let data = #"{"choices":[{"message":{"role":"assistant","content":"the summary"}}]}"#.data(using: .utf8)!
    #expect(SummaryLLMClient.parseContent(data) == "the summary")
    #expect(SummaryLLMClient.parseContent(Data("{}".utf8)) == nil)
}
