//
//  HTMLUtils.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import Foundation
import SwiftSoup
import SwiftUI

struct HTMLUtils {

    public static func convertHTMLToPlainText(html: String) -> String {
        do {
            let document: Document = try SwiftSoup.parse(html)
            return try document.text()
        } catch {
            print("Error parsing HTML to plain text with SwiftSoup: \(error). Falling back to regex.")
            return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        }
    }
    
    public static func attributedStringFromHTML(htmlString: String) -> AttributedString? {
        guard let data = htmlString.data(using: .utf8) else { return nil }
        if let nsAttributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return AttributedString(nsAttributedString)
        }
        return nil
    }

    public static func fetchLinkMetadata(from url: URL) async -> Card? {
        do {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 10
            let session = URLSession(configuration: configuration)

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let mimeType = httpResponse.mimeType, mimeType.hasPrefix("text/html"),
                  let htmlString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
            else {
                print("Failed to fetch HTML or not HTML content from URL: \(url). Status: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return nil
            }

            let title = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:title", "twitter:title"]) ?? extractTitleTagContent(htmlString: htmlString)
            let descriptionText = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:description", "twitter:description"]) // Renamed for clarity
            let imageUrlString = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:image", "twitter:image", "image_src"])
            let siteName = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:site_name", "application-name"])
            let cardUrlString = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:url", "twitter:url"]) ?? url.absoluteString

            guard let finalTitle = title, !finalTitle.isEmpty else {
                print("Could not extract a suitable title from URL: \(url)")
                return nil
            }
            
            let finalCardUrl = URL(string: cardUrlString)?.absoluteString ?? url.absoluteString

            return Card(
                url: finalCardUrl,
                title: finalTitle,
                summary: descriptionText ?? "", // FIX: Use 'summary' parameter, passing the fetched description
                type: "link",
                image: imageUrlString,
                authorName: nil,
                authorUrl: nil,
                providerName: siteName,
                providerUrl: nil,
                html: nil,
                width: nil,
                height: nil,
                embedUrl: nil,
                blurhash: nil
            )

        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
            print("Error fetching metadata from URL \(url): Request timed out.")
            return nil
        } catch {
            print("Error fetching or parsing metadata from URL \(url): \(error)")
            return nil
        }
    }

    private static func extractTitleTagContent(htmlString: String) -> String? {
        if let range = htmlString.range(of: "<title.*?>(.*?)</title>", options: [.regularExpression, .caseInsensitive]) {
            let titleMatch = String(htmlString[range])
            var title = titleMatch.replacingOccurrences(of: "<title.*?>", with: "", options: [.regularExpression, .caseInsensitive])
            title = title.replacingOccurrences(of: "</title>", with: "", options: .caseInsensitive)
            return title.trimmingCharacters(in: .whitespacesAndNewlines).htmlUnescape()
        }
        return nil
    }

    private static func extractMetaTagContent(htmlString: String, propertyPatterns: [String]) -> String? {
        for pattern in propertyPatterns {
            let regexPattern = "<meta[^>]*?(?:property|name)=(['\"])s*\(pattern)\\1[^>]*?content=(['\"])(.*?)\\2[^>]*?>"
            
            if let range = htmlString.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) {
                let metaTagString = String(htmlString[range])
                
                if let contentRange = metaTagString.range(of: "content=(['\"])(.*?)\\1", options: [.regularExpression, .caseInsensitive]) {
                    let contentPart = String(metaTagString[contentRange])
                    var value = contentPart.replacingOccurrences(of: "content=(['\"])", with: "", options: [.regularExpression, .caseInsensitive])
                    value = String(value.dropLast())
                    
                    if !value.isEmpty {
                        return value.trimmingCharacters(in: .whitespacesAndNewlines).htmlUnescape()
                    }
                }
            }
        }
        return nil
    }
}

extension String {
    func htmlUnescape() -> String {
        var result = self
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}
