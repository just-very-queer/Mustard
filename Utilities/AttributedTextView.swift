//
//  AttributedTextView.swift
//  Mustard
//
//  Created by Vaibhav Srivastava on 21/02/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// A SwiftUI wrapper around `UITextView` that displays rich `NSAttributedString` content.
/// - Automatically sizes itself based on the text.
/// - Calls `onLinkTap` when a link is tapped.
struct AttributedTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    let maxLayoutWidth: CGFloat
    let onLinkTap: (URL) -> Void

    @Binding var desiredHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false       // Disable internal scrolling
        textView.backgroundColor = .clear       // Match SwiftUI background
        textView.textContainerInset = .zero     // Remove default padding
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.link      // Standard link color
        ]
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedString

        // Recalculate height after setting the text
        DispatchQueue.main.async {
            let fixedWidth = maxLayoutWidth
            let newSize = uiView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
            if desiredHeight != newSize.height {
                desiredHeight = newSize.height
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AttributedTextView

        init(_ parent: AttributedTextView) {
            self.parent = parent
        }

        /// Handle link taps. Returns `false` to prevent default behavior and pass URL back via `onLinkTap`.
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            if URL.scheme?.hasPrefix("http") == true || URL.scheme?.hasPrefix("https") == true {
                parent.onLinkTap(URL)
                return false
            }
            // If you have a custom mention scheme, e.g., "mention://username", handle it here:
            // else if URL.scheme == "mention" {
            //     let mention = URL.host ?? ""
            //     // parent.onMentionTap(mention)
            //     return false
            // }

            // Allow default handling for other URL schemes (like mailto:, tel:), if desired:
            return true
        }

        /// Prevent any text selection or editing.
        func textViewDidChangeSelection(_ textView: UITextView) {
            textView.selectedTextRange = nil
        }
    }
}
#endif
