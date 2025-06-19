// Mustard/Views/Composer/ComposerTextProcessor.swift
import SwiftUI

struct ComposerTextProcessor {
    func process(text: inout AttributedString) {
        // Step 1: Extract plain string to discard old, fragmented attributes.
        // This is crucial for the "rebuild-on-keystroke" strategy.
        let plainString = String(text.characters)

        // Step 2: Create a fresh AttributedString from the plain string.
        // This ensures we start with a clean slate, no prior attributes.
        var newText = AttributedString(plainString)

        // Step 2a: Apply a base font to the entire new string.
        // This ensures that text not matching any pattern still has a default style.
        // You might want to make this font configurable later.
        newText.swiftUI.font = .body

        // Step 3: Find all pattern matches in the plain string.
        // Using the combinedRegex for efficiency.
        let matches = plainString.matches(of: ComposerTextPattern.combinedRegex)

        for match in matches {
            // Ensure the match's range can be converted to a range in the AttributedString.
            guard let rangeInNewText = Range(match.range, in: newText) else { continue }

            let matchedSubstring = plainString[match.range]

            // Determine which pattern type was matched.
            // This logic assumes patterns are somewhat distinct (e.g., @ for mention, # for hashtag).
            // More complex disambiguation might be needed if patterns overlap significantly.
            var patternType: ComposerTextPattern?
            if matchedSubstring.starts(with: "@") {
                patternType = .mention
            } else if matchedSubstring.starts(with: "#") {
                patternType = .hashtag
            } else if matchedSubstring.lowercased().starts(with: "http://") || matchedSubstring.lowercased().starts(with: "https://") {
                // Check for http or https for URLs, case-insensitively
                patternType = .url
            }

            // Step 4: Apply our custom 'textPattern' attribute to the matched range.
            // This doesn't apply visual styling directly, only marks the range.
            if let determinedPatternType = patternType {
                newText[rangeInNewText].textPattern = determinedPatternType
            }
        }

        // Step 5: Perform the "nuclear replacement".
        // The TextEditor's binding will be updated with this fully rebuilt AttributedString.
        text = newText
    }
}
