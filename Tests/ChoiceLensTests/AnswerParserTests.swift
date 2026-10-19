import Testing
@testable import ChoiceLens

struct AnswerParserTests {
    @Test func returnsOptionText() {
        #expect(AnswerParser.displayAnswer(from: "ANSWER: Mitochondria\nIt produces ATP.") == "Mitochondria")
    }

    @Test func toleratesMarkdownEmphasis() {
        #expect(AnswerParser.displayAnswer(from: "**ANSWER:** Paris\nCapital of France.") == "Paris")
        #expect(AnswerParser.displayAnswer(from: "**ANSWER: Paris**") == "Paris")
    }

    @Test func isCaseInsensitiveAndAcceptsDash() {
        #expect(AnswerParser.displayAnswer(from: "answer - Osmosis") == "Osmosis")
    }

    @Test(arguments: ["ANSWER: B) Paris", "ANSWER: B. Paris", "ANSWER: (B) Paris", "ANSWER: B - Paris", "ANSWER: B: Paris"])
    func stripsOptionLetterLabel(response: String) {
        #expect(AnswerParser.displayAnswer(from: response) == "Paris")
    }

    @Test func keepsBareLetterWhenThatIsAllTheModelGave() {
        #expect(AnswerParser.displayAnswer(from: "ANSWER: C\nBecause…") == "C")
    }

    @Test func stripsQuotesAndTrailingPeriod() {
        #expect(AnswerParser.displayAnswer(from: "ANSWER: \u{201C}Photosynthesis.\u{201D}") == "Photosynthesis")
        #expect(AnswerParser.displayAnswer(from: "ANSWER: 3.14.") == "3.14")
    }

    @Test func ignoresReasoningBlock() {
        let response = "<think>Maybe ANSWER: Wrong</think>\nANSWER: Right\nReason."
        #expect(AnswerParser.displayAnswer(from: response) == "Right")
    }

    @Test(arguments: ["ANSWER: UNKNOWN\nThe text is cut off.", "ANSWER: unknown", "I can't tell.", "ANSWER:", ""])
    func returnsQuestionMarkWhenNoAnswer(response: String) {
        #expect(AnswerParser.displayAnswer(from: response) == "?")
    }

    @Test func truncatesLongAnswers() {
        let answer = AnswerParser.displayAnswer(from: "ANSWER: The quick brown fox jumps over the lazy dog")
        #expect(answer.count == AnswerParser.maxDisplayLength)
        #expect(answer.hasSuffix("…"))
        #expect(answer.hasPrefix("The quick brown fox"))
    }
}
