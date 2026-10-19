import Foundation

enum AIClient {
    /// Room for a short answer and reason, plus any reasoning a model emits first.
    private static let maxResponseTokens = 400
    private static let instructions = """
    You are Promptly, a personal learning and practice helper. Analyze the multiple-choice question in the user-provided OCR text. The text comes from the whole screen, so it may include unrelated menus, buttons, tabs, or other windows: ignore those and focus on the question. Answer options are often unlabeled, appearing as separate short lines after the question (for example radio buttons or clickable choices); treat them as the options even without letters or numbers. If it is clear enough to answer, start with exactly `ANSWER: ` followed by the text of the correct option as it appears on screen, without its letter or number label and without markdown, on one line. If that option is long, give only its first few words. On the next line, give a concise reason of at most two sentences. Only if no question with answer options is visible, or the text is too incomplete or ambiguous to choose, start with `ANSWER: UNKNOWN` and explain briefly on the next line. The ANSWER line must contain only the option text or the word UNKNOWN, never an explanation. Do not claim certainty when the OCR is unclear.
    """

    static func analyze(recognizedText: String, provider: AIProvider, apiKey: String) async throws -> String {
        switch provider {
        case .minimax:
            try await analyzeOpenAICompatible(
                recognizedText: recognizedText,
                apiKey: apiKey,
                endpoint: URL(string: "https://api.minimax.io/v1/chat/completions")!,
                model: provider.defaultModel,
                includeMiniMaxThinkingControl: true,
                providerName: provider.displayName
            )
        case .openAI:
            try await analyzeOpenAICompatible(
                recognizedText: recognizedText,
                apiKey: apiKey,
                endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
                model: provider.defaultModel,
                includeMiniMaxThinkingControl: false,
                providerName: provider.displayName
            )
        case .anthropic:
            try await analyzeAnthropic(recognizedText: recognizedText, apiKey: apiKey)
        }
    }

    private static func analyzeOpenAICompatible(
        recognizedText: String,
        apiKey: String,
        endpoint: URL,
        model: String,
        includeMiniMaxThinkingControl: Bool,
        providerName: String
    ) async throws -> String {
        let body = OpenAICompatibleRequest(
            model: model,
            thinking: includeMiniMaxThinkingControl ? Thinking(type: "disabled") : nil,
            temperature: 0.1,
            maxCompletionTokens: maxResponseTokens,
            messages: [
                ChatMessage(role: "system", content: instructions),
                ChatMessage(role: "user", content: recognizedText)
            ]
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await perform(request, providerName: providerName)
        let completion = try JSONDecoder().decode(OpenAICompatibleResponse.self, from: data)
        guard let answer = completion.choices.first?.message.content, !answer.isEmpty else {
            throw ClientError.emptyAnswer(providerName)
        }
        return answer
    }

    private static func analyzeAnthropic(recognizedText: String, apiKey: String) async throws -> String {
        let body = AnthropicRequest(
            model: AIProvider.anthropic.defaultModel,
            maxTokens: maxResponseTokens,
            temperature: 0.1,
            system: instructions,
            messages: [ChatMessage(role: "user", content: recognizedText)]
        )
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await perform(request, providerName: AIProvider.anthropic.displayName)
        let completion = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let answer = completion.content.first(where: { $0.type == "text" })?.text, !answer.isEmpty else {
            throw ClientError.emptyAnswer(AIProvider.anthropic.displayName)
        }
        return answer
    }

    private static func perform(_ request: URLRequest, providerName: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "No error details returned."
            throw ClientError.api(provider: providerName, status: http.statusCode, detail: detail)
        }
        return data
    }
}

private struct OpenAICompatibleRequest: Encodable {
    let model: String
    let thinking: Thinking?
    let temperature: Double
    let maxCompletionTokens: Int
    let messages: [ChatMessage]

    enum CodingKeys: String, CodingKey {
        case model, thinking, temperature, messages
        case maxCompletionTokens = "max_completion_tokens"
    }
}

private struct Thinking: Encodable { let type: String }
private struct ChatMessage: Codable { let role: String; let content: String }
private struct OpenAICompatibleResponse: Decodable { let choices: [Choice] }
private struct Choice: Decodable { let message: ChatMessage }

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let temperature: Double
    let system: String
    let messages: [ChatMessage]

    enum CodingKeys: String, CodingKey {
        case model, temperature, system, messages
        case maxTokens = "max_tokens"
    }
}

private struct AnthropicResponse: Decodable { let content: [AnthropicContent] }
private struct AnthropicContent: Decodable { let type: String; let text: String? }

private enum ClientError: LocalizedError {
    case invalidResponse
    case api(provider: String, status: Int, detail: String)
    case emptyAnswer(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The model service returned an invalid response."
        case let .api(provider, status, detail): "\(provider) returned HTTP \(status): \(detail.prefix(180))"
        case let .emptyAnswer(provider): "\(provider) returned no answer."
        }
    }
}
