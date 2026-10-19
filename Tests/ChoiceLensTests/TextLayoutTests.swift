import CoreGraphics
import Testing
@testable import ChoiceLens

/// Boxes use Vision's normalized coordinates: origin at the bottom left.
private func line(_ text: String, x: CGFloat, top: CGFloat, width: CGFloat = 0.2, height: CGFloat = 0.02) -> RecognizedLine {
    RecognizedLine(text: text, box: CGRect(x: x, y: top - height, width: width, height: height))
}

struct TextLayoutTests {
    @Test func ordersLinesTopToBottom() {
        let lines = [
            line("B. Lyon", x: 0.1, top: 0.6),
            line("What is the capital of France?", x: 0.1, top: 0.8),
            line("A. Paris", x: 0.1, top: 0.7)
        ]
        #expect(TextLayout.readingOrder(lines) == "What is the capital of France?\nA. Paris\nB. Lyon")
    }

    @Test func ordersSideBySideOptionsLeftToRight() {
        let lines = [
            line("Which is a mammal?", x: 0.1, top: 0.8),
            line("Shark", x: 0.5, top: 0.7),
            line("Whale", x: 0.1, top: 0.701)
        ]
        #expect(TextLayout.readingOrder(lines) == "Which is a mammal?\nWhale\nShark")
    }

    @Test func treatsSlightlyOffsetBoxesAsOneRow() {
        let lines = [
            line("right", x: 0.6, top: 0.505),
            line("left", x: 0.1, top: 0.5)
        ]
        #expect(TextLayout.readingOrder(lines) == "left\nright")
    }

    @Test func skipsBlankLines() {
        let lines = [line("  ", x: 0.1, top: 0.9), line("Question", x: 0.1, top: 0.8)]
        #expect(TextLayout.readingOrder(lines) == "Question")
    }

    @Test func returnsEmptyForNoLines() {
        #expect(TextLayout.readingOrder([]) == "")
    }
}
