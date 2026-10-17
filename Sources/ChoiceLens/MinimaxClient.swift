import Foundation

enum MinimaxClient {
    private static let endpoint = URL(string: "https://api.minimax.io/v1/chat/completions")!

    static func analyze(recognizedText: String, apiKey: String) async throws -> String {
        let instructions = """
        You are Promptly, a personal learning and practice helper. Analyze the multiple-choice question in the user-provided OCR text. If it is clear enough to answer, start with exactly `ANSWER: ` followed by the selected option letter, then give a concise reason of at most two sentences. If the text is incomplete, ambiguous, or is not a multiple-choice question, start with `ANSWER: UNKNOWN` and explain briefly. Do not claim certainty when the OCR is unclear.
        """
        let body = ChatRequest(
            model: "MiniMax-M3",
            thinking: Thinking(type: "disabled"),
            temperature: 0.1,
            maxCompletionTokens: 220,
            messages: [
                Message(role: "system", content: instructions),
                Message(role: "user", content: recognizedText)
            ]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "No error details returned."
            throw ClientError.api(status: http.statusCode, detail: detail)
        }

        let completion = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let answer = completion.choices.first?.message.content, !answer.isEmpty else {
            throw ClientError.emptyAnswer
        }
        return answer
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let thinking: Thinking
    let temperature: Double
    let maxCompletionTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model, thinking, temperature, messages
        case maxCompletionTokens = "max_completion_tokens"
    }
}

private struct Thinking: Encodable { let type: String }
private struct Message: Codable { let role: String; let content: String }
private struct ChatResponse: Decodable { let choices: [Choice] }
private struct Choice: Decodable { let message: Message }

private enum ClientError: LocalizedError {
    case invalidResponse
    case api(status: Int, detail: String)
    case emptyAnswer

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The model service returned an invalid response."
        case let .api(status, detail): "MiniMax returned HTTP \(status): \(detail.prefix(180))"
        case .emptyAnswer: "MiniMax returned no answer."
        }
    }
}
