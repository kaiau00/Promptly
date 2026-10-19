import CoreGraphics

/// A line of recognized text with its Vision bounding box (normalized,
/// origin at the bottom left).
struct RecognizedLine {
    let text: String
    let box: CGRect
}

enum TextLayout {
    /// Joins lines in reading order: top to bottom, and left to right for
    /// lines that share a row, such as side-by-side answer options.
    static func readingOrder(_ lines: [RecognizedLine]) -> String {
        let visible = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let topToBottom = visible.sorted { $0.box.midY > $1.box.midY }
        return groupIntoRows(topToBottom)
            .flatMap { row in row.sorted { $0.box.minX < $1.box.minX } }
            .map(\.text)
            .joined(separator: "\n")
    }

    /// Lines whose vertical centers are within half a line height of a row's
    /// first line belong to that row.
    private static func groupIntoRows(_ lines: [RecognizedLine]) -> [[RecognizedLine]] {
        lines.reduce(into: [[RecognizedLine]]()) { rows, line in
            if let anchor = rows.last?.first,
               abs(anchor.box.midY - line.box.midY) < min(anchor.box.height, line.box.height) / 2 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
    }
}
