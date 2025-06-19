// Mustard/Views/Composer/ComposerTextPattern.swift
import SwiftUI

enum ComposerTextPattern: String, CaseIterable, Codable {
    case hashtag
    case mention
    case url

    // Regex for each pattern
    var pattern: String {
        switch self {
        case .hashtag: return "#\\w+" // Escaped for Swift string
        case .mention: return "@[\\w.-]+" // Escaped for Swift string
        case .url: return "(?i)https?://(?:www\\.)?\\S+(?:/|\\b)" // Escaped for Swift string
        }
    }

    // Associated color for styling
    var color: Color {
        switch self {
        case .hashtag: return .purple
        case .mention: return .indigo
        case .url: return .blue
        }
    }

    // A combined regex for efficient searching
    static var combinedRegex: Regex<AnyRegexOutput> {
        let patterns = ComposerTextPattern.allCases.map { $0.pattern }.joined(separator: "|")
        // We need to ensure that the regex compilation here is correct.
        // If this fails at runtime, the app will crash.
        // Consider adding error handling or ensuring patterns are valid.
        return try! Regex(patterns)
    }
}
