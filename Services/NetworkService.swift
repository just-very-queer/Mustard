//
//   NetworkService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

class NetworkService {
    static let shared = NetworkService()
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "NetworkService")
    private var rateLimiter = RateLimiter(capacity: 40, refillRate: 1.0)
    private let jsonDecoder = JSONDecoder()
    
    private init() {
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        jsonDecoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let iso8601FormatterWithFractionalSeconds = ISO8601DateFormatter()
            iso8601FormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601FormatterWithFractionalSeconds.date(from: dateString) {
                return date
            }

            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
    }

    func fetchData<T: Decodable>(url: URL, method: String, type: T.Type) async throws -> T {
        guard rateLimiter.tryConsume() else {
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let token = try? await KeychainHelper.shared.read(service: "MustardKeychain", account: "accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                logger.error("Invalid or server error response.")
                throw AppError(mastodon: .invalidResponse)
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Raw JSON response: \(jsonString)") // Log raw response
            }

            return try jsonDecoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            logDecodingError(decodingError)
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)
        } catch {
            throw AppError(type: .network(.requestFailed(underlyingError: error)), underlyingError: error)
        }
    }
    
    func postData<T: Decodable>(
        endpoint: String,
        body: [String: String],
        type: T.Type,
        baseURLOverride: URL? = nil,
        contentType: String = "application/json"
    ) async throws -> T {
        guard rateLimiter.tryConsume() else {
            throw AppError(mastodon: .rateLimitExceeded)
        }

        let url = try endpointURL(endpoint, baseURLOverride: baseURLOverride)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try buildBody(body: body, contentType: contentType)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        if let token = try? await KeychainHelper.shared.read(service: "MustardKeychain", account: "accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try jsonDecoder.decode(T.self, from: data)
    }

    func postAction(for postID: String, path: String) async throws {
        guard rateLimiter.tryConsume() else {
            throw AppError(mastodon: .rateLimitExceeded)
        }

        let url = try endpointURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = try? await KeychainHelper.shared.read(service: "MustardKeychain", account: "accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        _ = try await URLSession.shared.data(for: request)
    }

    func endpointURL(_ path: String, baseURLOverride: URL? = nil) throws -> URL {
        guard let base = baseURLOverride ?? URL(string: (try? await KeychainHelper.shared.read(service: "MustardKeychain", account: "baseURL")) ?? "") else {
            throw AppError(mastodon: .missingCredentials)
        }
        return base.appendingPathComponent(path)
    }

    func buildRequest(url: URL, method: String) async throws -> URLRequest {
        guard let token = try await KeychainHelper.shared.read(service: "MustardKeychain", account: "accessToken") else {
            throw AppError(mastodon: .missingCredentials)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.error("Invalid or server error response.")
            throw AppError(mastodon: .invalidResponse)
        }
    }

    private func buildBody(body: [String: String], contentType: String) throws -> Data? {
        switch contentType {
        case "application/json":
            return try JSONSerialization.data(withJSONObject: body)
        case "application/x-www-form-urlencoded":
            return body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                .joined(separator: "&")
                .data(using: .utf8)
        default:
            throw AppError(message: "Unsupported content type: \(contentType)")
        }
    }

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            logger.error("Data corrupted: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            logger.error("Key '\(key)' not found, Context: \(context.debugDescription)")
        case .valueNotFound(let value, let context):
            logger.error("Value '\(value)' not found, Context: \(context.debugDescription)")
        case .typeMismatch(let type, let context):
            logger.error("Type '\(type)' mismatch, Context: \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown decoding error")
        }
    }
}
