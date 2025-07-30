//
//  SwiftUIAttributedTextView.swift
//  Mustard
//
//  Created by Jules on 30/07/25.
//

import SwiftUI

/// A pure SwiftUI view that displays an `NSAttributedString` and handles link taps.
/// This view replaces the need for a `UIViewRepresentable` wrapper around `UITextView` for displaying rich text.
struct SwiftUIAttributedTextView: View {

    let attributedString: NSAttributedString
    let onLinkTap: (URL) -> Void

    /// A computed property to convert the `NSAttributedString` to a SwiftUI `AttributedString`.
    /// This conversion is done once when the view is created.
    private var swiftUIAttributedString: AttributedString {
        do {
            return try AttributedString(attributedString, including: \.swiftUI)
        } catch {
            // If conversion fails, log the error and return a plain text version.
            print("Error converting NSAttributedString to AttributedString: \(error)")
            return AttributedString(attributedString.string)
        }
    }

    var body: some View {
        Text(swiftUIAttributedString)
            .environment(\.openURL, OpenURLAction { url in
                // Intercept the URL tap.
                onLinkTap(url)
                // Return .handled to indicate that we've taken care of it.
                return .handled
            })
    }
}
