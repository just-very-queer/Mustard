//
//  SwiftSoupUtils.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import SwiftSoup
import Foundation // To use the URL type

struct SwiftSoupUtils {
    // Converts HTML string to plain text and may throw an error
    static func convertHTMLToPlainText(html: String) throws -> String {
        do {
            let document = try SwiftSoup.parse(html) // This throws
            return try document.text()
        } catch {
            throw error // Propagate the error instead of returning the original HTML
        }
    }
    
    // Extracts links from an HTML string
    static func extractLinks(from html: String) throws -> [URL] {
        do {
            let document = try SwiftSoup.parse(html) // This throws
            let elements = try document.select("a[href]").array() // Find all anchor tags with href attributes
            return elements.compactMap { element in
                if let href = try? element.attr("href"), let url = URL(string: href) {
                    return url // Create URL from the href attribute and return
                }
                return nil
            }
        } catch {
            throw error // Propagate the error if parsing fails
        }
    }
}

