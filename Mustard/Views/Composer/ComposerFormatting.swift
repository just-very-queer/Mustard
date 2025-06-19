// Mustard/Views/Composer/ComposerFormatting.swift
import SwiftUI

/// The main formatting definition for the composer.
struct ComposerFormattingDefinition: AttributedTextFormattingDefinition {
    typealias Scope = AttributeScopes.ComposerAttributes

    // Defines the set of constraints to apply.
    // Order can sometimes matter if constraints interact.
    var body: some AttributedTextFormattingDefinition<Scope> {
        PatternColorConstraint()
        URLUnderlineConstraint()
        // Potentially other constraints like custom font weights could be added here.
    }
}

/// Constraint that applies colors based on the custom `textPattern` attribute.
private struct PatternColorConstraint: AttributedTextValueConstraint {
    typealias Scope = AttributeScopes.ComposerAttributes
    // We are targeting the standard SwiftUI ForegroundColorAttribute.
    typealias AttributeKey = AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute

    func constrain(_ container: inout AttributeContainer) {
        // If our custom textPattern attribute is present...
        if let pattern = container.textPattern {
            // ...set the foregroundColor to the pattern's defined color.
            container.foregroundColor = pattern.color
        } else {
            // ...otherwise, ensure no specific color is set, allowing default text color.
            container.foregroundColor = nil
        }
    }
}

/// Constraint that applies an underline style only to URLs.
private struct URLUnderlineConstraint: AttributedTextValueConstraint {
    typealias Scope = AttributeScopes.ComposerAttributes
    // We are targeting the standard SwiftUI UnderlineStyleAttribute.
    typealias AttributeKey = AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute

    func constrain(_ container: inout AttributeContainer) {
        // If our custom textPattern attribute is present AND it's a URL...
        if let patternType = container.textPattern, patternType == .url {
            // ...apply a single underline.
            container.underlineStyle = .single
        } else {
            // ...otherwise, ensure no underline is applied.
            container.underlineStyle = nil
        }
    }
}

// Note: The original prompt used `Attributes` as the type for `container` in `constrain`.
// The correct type is `AttributeContainer` for `AttributedTextValueConstraint`.
// I have made this correction in the generated code.
