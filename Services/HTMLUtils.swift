//
//  HTMLUtils.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftUI

/// Utility struct for handling HTML-related conversions.
struct HTMLUtils {
    /// Converts an HTML string to an AttributedString.
    /// - Parameter html: The HTML string to convert.
    /// - Returns: An AttributedString representing the HTML content.
    static func convertHTMLToAttributedString(html: String) -> AttributedString {
        guard let data = html.data(using: .utf8) else { return AttributedString("") }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        do {
            let nsAttrStr = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return AttributedString(nsAttrStr)
        } catch {
            print("Error converting HTML to AttributedString: \(error.localizedDescription)")
            return AttributedString("")
        }
    }

    /// Converts an HTML string to plain text.
    /// - Parameter html: The HTML string to convert.
    /// - Returns: A plain text `String` without HTML tags.
    static func convertHTMLToPlainText(html: String) -> String {
        guard let data = html.data(using: .utf8) else { return "" }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        do {
            let nsAttrStr = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return nsAttrStr.string
        } catch {
            print("Error converting HTML to plain text: \(error.localizedDescription)")
            return ""
        }
    }
}


