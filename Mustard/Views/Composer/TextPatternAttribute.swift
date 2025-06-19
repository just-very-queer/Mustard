// Mustard/Views/Composer/TextPatternAttribute.swift
import SwiftUI

// 1. The custom attribute key
struct TextPatternAttribute: CodableAttributedStringKey, Sendable {
    typealias Value = ComposerTextPattern
    static var name = "app.mustard.TextPatternAttribute"
    // CRITICAL: Prevents styles from "bleeding" to new characters
    // when the user types adjacent to an already styled pattern.
    static var inheritedByAddedText: Bool = false
}

// 2. The custom attribute scope
extension AttributeScopes {
    struct ComposerAttributes: AttributeScope {
        let textPattern: TextPatternAttribute
        let swiftUI: SwiftUIAttributes // Includes default SwiftUI attributes like font, foregroundColor etc.
    }

    var composer: ComposerAttributes.Type { ComposerAttributes.self }
}

// 3. Convenience accessor for dynamic lookup
// This allows us to use dot syntax like `attributes.composer.textPattern`
extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.ComposerAttributes, T>) -> T {
        self[T.self]
    }
}
