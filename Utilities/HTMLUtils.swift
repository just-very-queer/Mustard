import Foundation

struct HTMLUtils {

    public static func fetchLinkMetadata(from url: URL) async -> Card? {
        do {
            // Set a timeout for the request
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 10 // 10 seconds timeout for the request
            configuration.timeoutIntervalForResource = 10 // 10 seconds timeout for the resource
            let session = URLSession(configuration: configuration)

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let mimeType = httpResponse.mimeType, mimeType.hasPrefix("text/html"),
                  let htmlString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) // Try common encodings
            else {
                print("Failed to fetch HTML or not HTML content from URL: \(url). Status: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return nil
            }

            let title = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:title", "twitter:title"]) ?? extractTitleTagContent(htmlString: htmlString)
            let description = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:description", "twitter:description"])
            let imageUrlString = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:image", "twitter:image", "image_src"]) // Added image_src as a fallback
            let siteName = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:site_name", "application-name"])
            let cardUrlString = extractMetaTagContent(htmlString: htmlString, propertyPatterns: ["og:url", "twitter:url"]) ?? url.absoluteString

            // Ensure we have at least a title and a URL.
            guard let finalTitle = title, !finalTitle.isEmpty else {
                print("Could not extract a suitable title from URL: \(url)")
                return nil
            }
            
            let finalCardUrl = URL(string: cardUrlString)?.absoluteString ?? url.absoluteString

            return Card(
                url: finalCardUrl,
                title: finalTitle,
                description: description ?? "",
                type: "link",
                image: imageUrlString,
                authorName: nil,
                authorUrl: nil,
                providerName: siteName,
                providerUrl: nil, // Usually, the provider URL is the domain of the main URL
                html: nil,
                width: nil,
                height: nil,
                embedUrl: nil, // For generic link types, embedUrl is often nil
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
            // Remove <title> and </title> tags, then unescape basic HTML entities
            var title = titleMatch.replacingOccurrences(of: "<title.*?>", with: "", options: [.regularExpression, .caseInsensitive])
            title = title.replacingOccurrences(of: "</title>", with: "", options: .caseInsensitive)
            return title.trimmingCharacters(in: .whitespacesAndNewlines).htmlUnescape()
        }
        return nil
    }

    private static func extractMetaTagContent(htmlString: String, propertyPatterns: [String]) -> String? {
        for pattern in propertyPatterns {
            // Regex to find <meta ... (property|name)="..." ... content="..." ... >
            // This regex tries to be flexible with attribute order and quotes.
            let regexPattern = "<meta[^>]*?(?:property|name)=(['\"])s*\(pattern)\\1[^>]*?content=(['\"])(.*?)\\2[^>]*?>"
            
            if let range = htmlString.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) {
                // The actual content is in the 3rd capture group (index 2 for ranges)
                // However, String.range(of:options:) for regex doesn't directly give capture groups.
                // We need to extract the whole meta tag and then parse the content attribute from it.
                let metaTagString = String(htmlString[range])
                
                // Extract content value from the meta tag string
                if let contentRange = metaTagString.range(of: "content=(['\"])(.*?)\\1", options: [.regularExpression, .caseInsensitive]) {
                    let contentPart = String(metaTagString[contentRange])
                    // Remove 'content="' and the closing quote
                    var value = contentPart.replacingOccurrences(of: "content=(['\"])", with: "", options: [.regularExpression, .caseInsensitive])
                    value = String(value.dropLast()) // Remove the last quote
                    
                    if !value.isEmpty {
                        return value.trimmingCharacters(in: .whitespacesAndNewlines).htmlUnescape()
                    }
                }
            }
        }
        return nil
    }
}

// Basic HTML unescaping extension
extension String {
    func htmlUnescape() -> String {
        var result = self
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'") // Common alternative for apostrophe
        // Add more entities as needed, e.g., &nbsp; could be replaced with a space or removed
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}
