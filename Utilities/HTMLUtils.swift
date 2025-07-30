//
//  HTMLUtils.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import Foundation
import SwiftSoup
import SwiftUI

struct HTMLUtils {

    /// Converts a raw HTML string into plain text, stripping all tags.
    public static func convertHTMLToPlainText(html: String) -> String {
        do {
            let document: Document = try SwiftSoup.parse(html)
            return try document.text()
        } catch {
            print("Error parsing HTML to plain text with SwiftSoup: \(error). Falling back to regex.")
            return html.replacingOccurrences(
                of: "<[^>]+>",
                with: "",
                options: .regularExpression,
                range: nil
            )
        }
    }

    /// Converts an HTML string into an `NSAttributedString`. If conversion fails for any reason,
    /// it falls back to returning a plain‐text `NSAttributedString`.
    public static func nsAttributedStringFromHTML(htmlString: String) -> NSAttributedString {
        var processedHtmlString = htmlString
        var soupParsingError: Error? = nil

        do {
            let document: Document = try SwiftSoup.parse(htmlString)
            // Try to get body's HTML. If empty or nil, try the whole document's HTML.
            if let bodyHtml = try document.body()?.html(), !bodyHtml.isEmpty {
                processedHtmlString = bodyHtml
                // print("HTMLUtils: SwiftSoup successfully parsed body HTML.")
            } else {
                // Fallback to re-serializing the whole document if body is not suitable or empty
                processedHtmlString = try document.html()
                // print("HTMLUtils: SwiftSoup used full document re-serialization.")
            }
        } catch {
            soupParsingError = error
            // processedHtmlString remains the original htmlString
            // Error will be printed later if NSAttributedString conversion also fails,
            // or we can print it here unconditionally.
            print("HTMLUtils: SwiftSoup parsing/serialization error: \(error). Using original HTML string for NSAttributedString conversion.")
        }

        // If we can’t get UTF-8 data, immediately return a plain‐text fallback:
        guard let data = processedHtmlString.data(using: .utf8) else {
            // This fallback uses processedHtmlString which might be the original or SwiftSoup output
            print("HTMLUtils: Failed to convert processed HTML string to UTF-8 data. Falling back to plain string from processed HTML.")
            return NSAttributedString(string: processedHtmlString)
        }

        // Build our options dictionary. Note: .characterEncoding expects an NSNumber.
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: NSNumber(value: String.Encoding.utf8.rawValue)
        ]

        // Always try to create on the current thread, but guard against Objective-C exceptions
        // using an autoreleasepool for better memory management.

        // Default fallback uses processedHtmlString
        var result = NSAttributedString(string: processedHtmlString)

        autoreleasepool {
            do {
                let initialResult = try NSAttributedString(
                    data: data,
                    options: options,
                    documentAttributes: nil
                )

                // Post-process to style mentions and hashtags
                let mutableAttributedString = NSMutableAttributedString(attributedString: initialResult)

                let fullRange = NSRange(location: 0, length: mutableAttributedString.length)

                mutableAttributedString.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
                    guard let url = value as? URL else { return }

                    // Check if the link is a hashtag or mention
                    let linkString = url.absoluteString
                    if linkString.contains("/tags/") { // Hashtag
                        mutableAttributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
                    } else if linkString.contains("@") || (linkString.contains("/users/") && !linkString.contains("/statuses/")) { // Mention
                        mutableAttributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
                    }
                }

                result = mutableAttributedString

                if let soupError = soupParsingError {
                    print("HTMLUtils: NSAttributedString conversion succeeded with original HTML after SwiftSoup failed with error: \(soupError)")
                }
            } catch {
                print("HTMLUtils: Error converting HTML to NSAttributedString: \(error). Falling back to plain string.")
            }
        }
        return result
    }

    /// Fetches Open Graph / Twitter Card metadata from the provided URL and maps it into a `Card` model.
    public static func fetchLinkMetadata(from url: URL) async -> Card? {
        do {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 10
            let session = URLSession(configuration: configuration)

            let (data, response) = try await session.data(from: url)

            guard
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                let mimeType = httpResponse.mimeType, mimeType.hasPrefix("text/html"),
                let htmlString = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .ascii)
            else {
                print(
                    "Failed to fetch HTML or not HTML content from URL: \(url). "
                  + "Status: \(String(describing: (response as? HTTPURLResponse)?.statusCode))"
                )
                return nil
            }

            let title = extractMetaTagContent(
                htmlString: htmlString,
                propertyPatterns: ["og:title", "twitter:title"]
            ) ?? extractTitleTagContent(htmlString: htmlString)

            let descriptionText = extractMetaTagContent(
                htmlString: htmlString,
                propertyPatterns: ["og:description", "twitter:description"]
            )

            let imageUrlString = extractMetaTagContent(
                htmlString: htmlString,
                propertyPatterns: ["og:image", "twitter:image", "image_src"]
            )

            let siteName = extractMetaTagContent(
                htmlString: htmlString,
                propertyPatterns: ["og:site_name", "application-name"]
            )

            let cardUrlString = extractMetaTagContent(
                htmlString: htmlString,
                propertyPatterns: ["og:url", "twitter:url"]
            ) ?? url.absoluteString

            guard let finalTitle = title, !finalTitle.isEmpty else {
                print("Could not extract a suitable title from URL: \(url)")
                return nil
            }

            let finalCardUrl = URL(string: cardUrlString)?.absoluteString ?? url.absoluteString

            return Card(
                url: finalCardUrl,
                title: finalTitle,
                summary: descriptionText ?? "",
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

    // MARK: - Private helper methods

    private static func extractTitleTagContent(htmlString: String) -> String? {
        if let range = htmlString.range(
            of: "<title.*?>(.*?)</title>",
            options: [.regularExpression, .caseInsensitive]
        ) {
            let titleMatch = String(htmlString[range])
            var title = titleMatch.replacingOccurrences(
                of: "<title.*?>",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            title = title.replacingOccurrences(of: "</title>", with: "", options: .caseInsensitive)
            return title.trimmingCharacters(in: .whitespacesAndNewlines).htmlUnescape()
        }
        return nil
    }

    private static func extractMetaTagContent(
        htmlString: String,
        propertyPatterns: [String]
    ) -> String? {
        for pattern in propertyPatterns {
            // Look for <meta property="og:..." content="..."> or <meta name="twitter:..." content="...">
            let regexPattern = "<meta[^>]*?(?:property|name)=(['\"])\\s*\(pattern)\\1[^>]*?content=(['\"])(.*?)\\2[^>]*?>"

            if let range = htmlString.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) {
                let metaTagString = String(htmlString[range])

                if let contentRange = metaTagString.range(
                    of: "content=(['\"])(.*?)\\1",
                    options: [.regularExpression, .caseInsensitive]
                ) {
                    let contentPart = String(metaTagString[contentRange])
                    var value = contentPart.replacingOccurrences(
                        of: "content=(['\"])",
                        with: "",
                        options: [.regularExpression, .caseInsensitive]
                    )
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
    /// Simple HTML entity unescaping (handles a few common entities).
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
