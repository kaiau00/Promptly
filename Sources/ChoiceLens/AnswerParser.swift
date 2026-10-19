import Foundation

/// Turns a model response that starts with `ANSWER: <option text>` into the
/// short text shown in the menu bar.
enum AnswerParser {
    static let maxDisplayLength = 28
    static let unknown = "?"

    private static let reasoningBlock = try! NSRegularExpression(
        pattern: #"<think>.*?</think>"#,
        options: [.dotMatchesLineSeparators, .caseInsensitive]
    )
    private static let answerLine = try! NSRegularExpression(
        pattern: #"ANSWER\s*[:\-]\s*([^\n]*)"#,
        options: .caseInsensitive
    )
    /// An option label such as "B)", "B.", "(B)", "B -" or "B:" before the option text.
    private static let optionLabel = try! NSRegularExpression(
        pattern: #"^\(?[A-F](?:\)|\.|:|\s+-)\s+(?=\S)"#
    )
    private static let wrappingCharacters = CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}")
        .union(.whitespaces)

    static func displayAnswer(from response: String) -> String {
        let cleaned = removeMarkdown(from: remove(reasoningBlock, from: response))
        guard let raw = firstCapture(of: answerLine, in: cleaned) else { return unknown }

        var answer = remove(optionLabel, from: raw.trimmingCharacters(in: .whitespaces))
        answer = answer.trimmingCharacters(in: wrappingCharacters)
        if answer.hasSuffix(".") { answer.removeLast() }
        answer = answer.trimmingCharacters(in: wrappingCharacters)

        guard !answer.isEmpty, !answer.uppercased().hasPrefix("UNKNOWN") else { return unknown }
        return truncated(answer)
    }

    private static func removeMarkdown(from text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    private static func remove(_ expression: NSRegularExpression, from text: String) -> String {
        expression.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )
    }

    private static func firstCapture(of expression: NSRegularExpression, in text: String) -> String? {
        guard let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func truncated(_ answer: String) -> String {
        guard answer.count > maxDisplayLength else { return answer }
        let kept = answer.prefix(maxDisplayLength - 1).trimmingCharacters(in: .whitespaces)
        return kept + "…"
    }
}
