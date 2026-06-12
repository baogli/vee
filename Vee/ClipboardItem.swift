import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let copiedAt: Date

    var preview: String {
        let collapsed = content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if collapsed.count <= 84 {
            return collapsed
        }

        return String(collapsed.prefix(81)) + "..."
    }

    var kindIcon: String? {
        if content.range(of: #"^https?://"#, options: .regularExpression) != nil {
            return "link"
        }

        if content.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil {
            return "envelope"
        }

        return nil
    }
}
