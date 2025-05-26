//
//  HTMLUtils.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import SwiftUI
import SafariServices
import CoreLocation
import Combine
import SwiftData
import SwiftSoup

struct HTMLUtils {
    
    /// Converts HTML content to plain text, ensuring better readability.
    static func convertHTMLToPlainText(html: String) -> String {
        do {
            // Remove <br> tags before parsing for better spacing
            let cleanedHtml = html.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: .regularExpression)
            let doc: Document = try SwiftSoup.parse(cleanedHtml)
            return try doc.text()
        } catch {
            print("Error converting HTML to plain text: \(error)")
            return html // Return original on failure
        }
    }
    
    /// Converts an HTML string into an `AttributedString` for rendering with rich text features.
    static func attributedStringFromHTML(htmlString: String) -> AttributedString? {
        guard let data = htmlString.data(using: .utf8) else { return nil }
        
        do {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            
            // Convert to SwiftUI AttributedString
            var swiftUIAttributedString = AttributedString(attributedString)
            
            // Apply additional styling
            applyDefaultStyles(to: &swiftUIAttributedString)
            
            return swiftUIAttributedString
        } catch {
            print("Error converting HTML to attributed string: \(error)")
            return nil
        }
    }
    
    /// Applies default text styling to the given `AttributedString`
    private static func applyDefaultStyles(to attributedString: inout AttributedString) {
        var container = AttributeContainer()
        
        // Use SwiftUI Font instead of UIFont
        container.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize)
        container.foregroundColor = .primary // Uses SwiftUI color, works with light/dark mode
        
        attributedString.setAttributes(container)
    }
}

extension URL {
    /// Detects the first valid URL in a given text string.
    static func detect(from content: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))?.url
    }
}
