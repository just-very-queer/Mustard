//
//  AttributedTextView.swift
//  Mustard
//
//  Created by Vaibhav Srivastava on 21/02/25. // Assuming 2025 based on original comment
//

import SwiftUI
import UIKit

struct AttributedTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    let maxLayoutWidth: CGFloat
    let onLinkTap: (URL) -> Void // Closure to handle link taps

    // Optional: Add callback for @mention taps if implemented in HTMLUtils
    // let onMentionTap: (String) -> Void

    @Binding var desiredHeight: CGFloat // Binding to report the calculated height

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false // Crucial: Disable scrolling within the view itself
        textView.backgroundColor = .clear // Blend with SwiftUI background
        textView.textContainerInset = .zero // Remove default padding
        textView.textContainer.lineFragmentPadding = 0 // Remove default padding
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.link // Use standard link color
            // Add other attributes like underline if desired
        ]
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedString
        // Calculate desired height after setting text
        DispatchQueue.main.async { // Ensure calculation happens after layout pass
            let fixedWidth = maxLayoutWidth
             // Use infinity for height to allow wrapping for calculation
            let newSize = uiView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
            if desiredHeight != newSize.height {
                desiredHeight = newSize.height
            }
        }
    }

    // --- Coordinator to handle delegate methods ---
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AttributedTextView

        init(_ parent: AttributedTextView) {
            self.parent = parent
        }

        // Handle link interactions - UPDATED METHOD SIGNATURE
        // Replaced textView(_:shouldInteractWith:in:interaction:)
        // with textView(_:shouldInteractWith:in:) to resolve iOS 17 deprecation
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            // Check if it's a standard web link
            if URL.scheme?.starts(with: "http") == true || URL.scheme?.starts(with: "https") == true {
                parent.onLinkTap(URL)
                return false // Prevent default opening behavior, handle with custom action (e.g., SafariView sheet)
            }
            // Example: Handle custom mention scheme (e.g., "mention://@username@instance")
            // else if URL.scheme == "mention" {
            //     let mention = URL.host ?? "" // Extract mention from URL
            //     // Ensure you have an onMentionTap handler in AttributedTextView if using this
            //     // parent.onMentionTap(mention)
            //     return false // Prevent default action for mentions too
            // }

            // Allow default interaction for other URL types (e.g., mailto:, tel:) if needed
            return true
        }

        // Disable text selection/editing interactions
        func textViewDidChangeSelection(_ textView: UITextView) {
            // Setting selectedTextRange to nil ensures text cannot be selected.
            textView.selectedTextRange = nil
        }

         // Optional: If you *only* want to handle specific schemes like http/https
         // and prevent *all* other default interactions (like mailto:, tel:),
         // you could modify the shouldInteractWith method like this:
         /*
         func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
             if URL.scheme?.starts(with: "http") == true || URL.scheme?.starts(with: "https") == true {
                 parent.onLinkTap(URL)
             }
             // Handle mentions if needed
             // else if URL.scheme == "mention" { ... }

             // Explicitly prevent default action for *all* URLs handled here or otherwise
             return false
         }
         */

        // Note: iOS 17 also introduced other methods like
        // textView(_:primaryActionFor:in:defaultAction:) and
        // textView(_:menuConfigurationFor:in:defaultMenu:)
        // for more customization of text item interactions, but they are not
        // needed just to fix this deprecation warning if the simpler
        // shouldInteractWith behavior is sufficient.

    }
}
