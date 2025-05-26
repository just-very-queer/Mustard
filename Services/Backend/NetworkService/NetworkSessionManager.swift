//
//  NetworkSessionManager.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 17/04/25.
//

import Foundation
import OSLog
import SwiftUI // Keep if AppError or other dependencies require it

public class NetworkSessionManager {
    // MARK: - Shared Instance
    public static let shared = NetworkSessionManager()

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "NetworkSessionManager")
    private let rateLimiter = RateLimiter(capacity: 40, refillRate: 1.0)

    // MARK: - JSON Coders (Accessible for reuse)
    public let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid date format: \(dateString)")
        }
        return decoder
    }()

    public static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // MARK: - Initialization
    private init() {
        // Private initializer for singleton
    }

    // MARK: - Core Request Execution

    /// Performs a network request, decodes the response, handles errors, rate limiting, and logging.
    /// - Parameters:
    ///   - request: The `URLRequest` to perform.
    ///   - responseType: The expected `Decodable` type.
    /// - Returns: Decoded response of type `T`.
    /// - Throws: `AppError` for network, decoding, or rate limiting issues.
    func performRequest<T: Decodable>(
        request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        guard await rateLimiter.tryConsume() else {
            logger.warning("Rate limit exceeded for request: \(request.url?.absoluteString ?? "Unknown URL")")
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }

        do {
            logRequest(request)
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data)
            try validateResponse(response, data: data)
            return try jsonDecoder.decode(T.self, from: data)
        } catch let urlError as URLError {
            logger.error("Network request failed with URLError: \(urlError.localizedDescription)")
            throw mapURLError(urlError)
        } catch let decodingError as DecodingError {
            logDecodingError(decodingError)
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)
        } catch let appError as AppError {
            // Rethrow known AppErrors (like validation errors)
            throw appError
        } catch {
            logger.error("Network request failed with unknown error: \(error.localizedDescription)")
            throw AppError(type: .other("Unknown network error"), underlyingError: error)
        }
    }

    /// Performs a network request and optionally decodes the response. Returns nil if decoding fails or data is empty.
    /// - Parameters:
    ///   - request: The `URLRequest` to perform.
    ///   - responseType: The expected `Decodable` type.
    /// - Returns: Decoded response of type `T` or nil.
    /// - Throws: `AppError` for network or rate limiting issues.
    func performRequestOptional<T: Decodable>(
        request: URLRequest,
        responseType: T.Type
    ) async throws -> T? {
        guard await rateLimiter.tryConsume() else {
            logger.warning("Rate limit exceeded for optional request: \(request.url?.absoluteString ?? "Unknown URL")")
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }

        do {
            logRequest(request)
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data)
            try validateResponse(response, data: data)

            guard !data.isEmpty else {
                 logger.debug("Received empty response body for optional decode, returning nil.")
                 return nil
             }

            // Attempt to decode, return nil on failure instead of throwing decoding error
            return try? jsonDecoder.decode(T.self, from: data)

        } catch let urlError as URLError {
            logger.error("Optional network request failed with URLError: \(urlError.localizedDescription)")
            throw mapURLError(urlError)
        } catch let appError as AppError {
            // Rethrow known AppErrors (like validation errors)
            throw appError
        } catch {
            logger.error("Optional network request failed with unknown error: \(error.localizedDescription)")
            throw AppError(type: .other("Unknown network error"), underlyingError: error)
        }
    }

    // MARK: - Request Building Helper (Moved here or keep in MastodonAPIService if it needs specific logic)

    /// Builds a `URLRequest` with common configurations (method, optional body, content type, auth token).
    /// Needs access token provided externally.
    func buildRequest(
        url: URL,
        method: String,
        body: [String: String]? = nil,
        contentType: String = "application/json",
        accessToken: String?
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            logger.debug("Authorization Header set.") // Simplified log
        } else {
            logger.debug("No Authorization Header set.")
        }

        if let body = body {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type") // Set content type header
            switch contentType.lowercased() {
            case "application/json":
                // Ensure body can be serialized to JSON
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            case "application/x-www-form-urlencoded":
                let formString = body
                    .compactMap { key, value in
                        guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                            return nil
                        }
                        return "\(key)=\(encodedValue)"
                    }
                    .joined(separator: "&")
                request.httpBody = formString.data(using: .utf8)
            default:
                logger.error("Unsupported content type: \(contentType)")
                throw AppError(message: "Unsupported content type: \(contentType)")
            }
            logger.debug("Request body set with content type: \(contentType)")
        }

        return request
    }

    // MARK: - Response Validation
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type received (not HTTPURLResponse).")
            throw AppError(mastodon: .invalidResponse)
        }

        logger.debug("Received HTTP response with status code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            logFailedResponse(response: httpResponse, data: data)
            // Map specific HTTP error codes
            switch httpResponse.statusCode {
            case 401: throw AppError(mastodon: .unauthorized)
            case 403: throw AppError(mastodon: .forbidden)
            case 404: throw AppError(mastodon: .notFound)
            // Add other specific mappings (e.g., 400 Bad Request, 429 Rate Limit)
            default: throw AppError(mastodon: .serverError(status: httpResponse.statusCode))
            }
        }
    }

    // MARK: - Error Mapping
    private func mapURLError(_ urlError: URLError) -> AppError {
         switch urlError.code {
         case .notConnectedToInternet, .networkConnectionLost:
             return AppError(network: .networkError, underlyingError: urlError)
         case .timedOut:
             return AppError(network: .timedOut, underlyingError: urlError)
         default:
             return AppError(network: .requestFailed(underlyingError: urlError), underlyingError: urlError)
         }
    }

    // MARK: - Logging Methods (Kept private)
    private func logRequest(_ request: URLRequest) {
        logger.info("Request → \(request.url?.absoluteString ?? "Unknown URL") [\(request.httpMethod ?? "GET")]")
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logger.debug("Request Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("Request Body: \(bodyString)")
        }
    }

    private func logResponse(_ response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        logger.debug("Response ← Status: \(httpResponse.statusCode)")
        logger.debug("Response Headers: \(httpResponse.allHeaderFields)")
        if let responseBody = String(data: data, encoding: .utf8) {
            let previewLength = 500
            if responseBody.count > previewLength {
                 logger.debug("Response Body (preview): \(responseBody.prefix(previewLength))...")
            } else {
                 logger.debug("Response Body: \(responseBody)")
            }
        }
    }

    private func logFailedResponse(response: HTTPURLResponse, data: Data) {
        let bodyString = String(data: data, encoding: .utf8) ?? "Unable to decode response body."
        logger.error("Server returned status \(response.statusCode). Body: \(bodyString)")
    }

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            logger.error("Data corrupted: \(context.debugDescription), Context: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .keyNotFound(let key, let context):
            logger.error("Key '\(key.stringValue)' not found: \(context.debugDescription), Context: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .valueNotFound(let value, let context):
            logger.error("Value of type '\(value)' not found: \(context.debugDescription), Context: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .typeMismatch(let type, let context):
            logger.error("Type '\(type)' mismatch: \(context.debugDescription), Context: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        @unknown default:
            logger.error("Unknown DecodingError occurred.")
        }
    }
}

// Define HTTPMethod and PostContext if they are not defined elsewhere
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH" // Added PATCH if needed for profile updates etc.
}

struct PostContext: Decodable {
    let ancestors: [Post]
    let descendants: [Post]
}
