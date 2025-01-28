//
//  NetworkService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  Updated to handle custom KeyDecodingStrategy for "vapid_key".
//

import Foundation
import AuthenticationServices
import OSLog
import SwiftUI
import CoreLocation

/// A service responsible for all network requests in the Mustard app, including
/// Mastodon API calls, OAuth flows, and general fetch/post actions.
final class NetworkService {
    // MARK: - Singleton
    static let shared = NetworkService()

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "NetworkService")
    private let rateLimiter = RateLimiter(capacity: 40, refillRate: 1.0)
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private let keychainService = "MustardKeychain"

    // MARK: - Initialization
    private init() {
            jsonDecoder = JSONDecoder()
            jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
            // Remove the custom date decoding strategy
            // jsonDecoder.dateDecodingStrategy = .custom { ... }

            jsonEncoder = JSONEncoder()
            jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
            jsonEncoder.dateEncodingStrategy = .iso8601
    }
    
    private func makeRegisterResponseDecoder() -> JSONDecoder {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            // You can add a dateDecodingStrategy here if needed for RegisterResponse,
            // but it's likely not necessary as it doesn't contain any Date properties.
            return decoder
        }

    // MARK: - Public API

    /// Performs a GET (or other method) request for `url` and decodes the result into type `T`.
    /// - Throws: `AppError` if the user is missing credentials or a network/decoding error occurs.
    func fetchData<T: Decodable>(
        url: URL,
        method: String = "GET",
        type: T.Type
    ) async throws -> T {
        // Requires an access token for most Mastodon endpoints
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }

        // Log the baseURL being used
        let baseURL = try await KeychainHelper.shared.read(service: keychainService, account: "baseURL")
        logger.debug("Using baseURL: \(baseURL ?? "nil")")

        // Build the request
        let request = try buildRequest(url: url, method: method, accessToken: accessToken)

        // Perform the request and decode
        return try await performRequest(request, responseType: T.self)
    }

    /// Performs a POST request to an endpoint with a given body, optionally requiring auth.
    /// - Parameters:
    ///   - endpoint: Relative path (e.g. "/api/v1/apps").
    ///   - body: A dictionary representing the form or JSON body to send.
    ///   - responseType: The decodable model to parse from the server response.
    ///   - baseURLOverride: If non-nil, use this URL as the base for the endpoint.
    ///   - contentType: Either JSON or URL-encoded form data.
    ///   - requireAuth: Whether to attach an existing access token.
    func postData<T: Decodable>(
        endpoint: String,
        body: [String: String],
        responseType: T.Type,
        baseURLOverride: URL? = nil,
        contentType: String = "application/json",
        requireAuth: Bool = true
    ) async throws -> T {
        // Optionally fetch the token if required
        let accessToken: String?
        if requireAuth {
            guard let token = await fetchAccessToken() else {
                throw AppError(mastodon: .missingCredentials)
            }
            accessToken = token
        } else {
            accessToken = nil
        }

        // Resolve the full URL
        let url = try await endpointURL(endpoint, baseURLOverride: baseURLOverride)

        // Build the request with body and content type
        var request = try buildRequest(
            url: url,
            method: "POST",
            body: body,
            contentType: contentType,
            accessToken: accessToken
        )
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        // Perform the request and decode
        return try await performRequest(request, responseType: T.self)
    }

    /// Performs a simple POST action that doesn't return anything we need to decode.
    /// E.g. liking or reblogging a post. Expects 2xx to confirm success.
    func postAction(
        for postID: String,
        path: String,
        baseURLOverride: URL? = nil
    ) async throws {
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }

        let url = try await endpointURL(path, baseURLOverride: baseURLOverride)
        let request = try buildRequest(url: url, method: "POST", accessToken: accessToken)

        // Perform the request without decoding
        _ = try await performRequest(request, responseType: Data.self)
    }

    /// Registers the app with a Mastodon instance to get client credentials.
    /// - Returns: An `OAuthConfig` containing the clientId, clientSecret, redirectUri, etc.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
            let body = [
                "client_name": "Mustard",
                "redirect_uris": "mustard://oauth-callback",
                "scopes": "read write follow push",
                "website": "https://example.com"
            ]
            let requestURL = instanceURL.appendingPathComponent("/api/v1/apps")
            var request = URLRequest(url: requestURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                logger.error("Failed to serialize request body: \(error.localizedDescription)")
                throw AppError(mastodon: .encodingError, underlyingError: error)
            }
            
            // Send the HTTP request
            logger.info("Sending OAuth app registration request to \(requestURL.absoluteString)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Validate the HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type received.")
                throw AppError(mastodon: .invalidResponse)
            }
            
            logger.debug("Received HTTP response with status code: \(httpResponse.statusCode)")
            
            // Check for non-200 status code
            guard httpResponse.statusCode == 200 else {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                logger.error("Request failed with status code \(httpResponse.statusCode). Response body: \(responseBody)")
                throw AppError(mastodon: .serverError(status: httpResponse.statusCode))
            }
            
            // Decode the response body using the dedicated decoder
            let registerResponse: RegisterResponse
            do {
                let registerDecoder = makeRegisterResponseDecoder()
                registerResponse = try registerDecoder.decode(RegisterResponse.self, from: data)
                logger.info("Successfully registered OAuth app with client ID: \(registerResponse.clientId)")
            } catch {
                logger.error("Failed to decode register response: \(error.localizedDescription)")
                if let responseBody = String(data: data, encoding: .utf8) {
                    logger.debug("Response body for debugging: \(responseBody)")
                }
                throw AppError(mastodon: .decodingError, underlyingError: error)
            }
            
            // Return the OAuth configuration
            return OAuthConfig(
                clientId: registerResponse.clientId,
                clientSecret: registerResponse.clientSecret,
                redirectUri: registerResponse.redirectUri,
                scope: "read write follow push"
            )
        }

    /// Exchanges the authorization code for an access token on the given instance.
    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws {
        let body: [String: String] = [
            "grant_type":    "authorization_code",
            "code":          code,
            "client_id":     config.clientId,
            "client_secret": config.clientSecret,
            "redirect_uri":  config.redirectUri,
            "scope":         config.scope
        ]

        // Exchange the code without requiring auth
        let tokenResponse: TokenResponse = try await postData(
            endpoint: "/oauth/token",
            body: body,
            responseType: TokenResponse.self,
            baseURLOverride: instanceURL,
            contentType: "application/x-www-form-urlencoded",
            requireAuth: false
        )

        // Save the newly obtained token in Keychain
        try await KeychainHelper.shared.save(
            tokenResponse.accessToken,
            service: keychainService,
            account: "accessToken"
        )

        logger.info("Exchanged authorization code for access token (masked).")
    }

    /// Fetches the current user's profile from the Mastodon server (via `/api/v1/accounts/verify_credentials`).
    func fetchCurrentUser(
        instanceURL: URL? = nil
    ) async throws -> User {
        let url: URL
        if let overrideURL = instanceURL {
            url = overrideURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        } else {
            // If no override, read the baseURL from Keychain
            guard let baseURLString = await loadFromKeychain(key: "baseURL"),
                  let baseURL = URL(string: baseURLString) else {
                throw AppError(mastodon: .missingCredentials)
            }
            url = baseURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        }

        let user: User = try await fetchData(
            url: url,
            method: "GET",
            type: User.self
        )

        logger.info("Successfully fetched current user: \(user.username, privacy: .public)")
        return user
    }

    // MARK: - Private Methods

    /// Constructs a full URL from a path and optional override base URL.
    /// If no override is given, it reads the base from Keychain.
    private func endpointURL(
        _ path: String,
        baseURLOverride: URL? = nil
    ) async throws -> URL {
        if let override = baseURLOverride {
            return override.appendingPathComponent(path)
        }

        guard let baseURLString = await loadFromKeychain(key: "baseURL"),
              let baseURL = URL(string: baseURLString) else {
            throw AppError(mastodon: .missingCredentials)
        }
        return baseURL.appendingPathComponent(path)
    }

    /// A generic function to execute a URLRequest, handle rate limiting, log, validate, and decode.
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        // Enforce rate limiting
        guard await rateLimiter.tryConsume() else {
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }

        do {
            // Log the outgoing request
            logRequest(request)

            // Execute the request
            let (data, response) = try await URLSession.shared.data(for: request)

            // Log the response
            logResponse(response, data: data)

            // Check HTTP status code
            try validateResponse(response, data: data)

            // Optionally log the JSON for debugging
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                logger.debug("JSON Response: \(jsonObject)")
            }

            // Decode the data into the specified type
            return try decodeResponse(data, type: responseType)

        } catch let urlError as URLError {
            logger.error("Network request failed with URLError: \(urlError.localizedDescription, privacy: .public)")
            throw handleURLError(urlError)

        } catch let decodingError as DecodingError {
            logDecodingError(decodingError)
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)

        } catch let appError as AppError {
            // If we explicitly threw an AppError upstream, rethrow
            throw appError

        } catch {
            logger.error("Network request failed with unknown error: \(error.localizedDescription, privacy: .public)")
            throw AppError(type: .other("Unknown network error"), underlyingError: error)
        }
    }

    /// Builds a URLRequest with optional JSON/x-www-form-urlencoded body and Bearer token.
    private func buildRequest(
        url: URL,
        method: String,
        body: [String: String]? = nil,
        contentType: String = "application/json",
        accessToken: String? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method

        // If we have a token, attach it in the Auth header
        if let token = accessToken {
            logger.debug("Using access token: \(token)")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            logger.debug("Access Token is nil (this may be intentional for certain calls).")
        }

        // Encode the body
        if let body = body {
            switch contentType.lowercased() {
            case "application/json":
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            case "application/x-www-form-urlencoded":
                let formString = body
                    .map {
                        "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    }
                    .joined(separator: "&")
                request.httpBody = formString.data(using: .utf8)
            default:
                throw AppError(message: "Unsupported content type: \(contentType)")
            }
        }

        return request
    }

    /// Checks that the response is HTTP and has a 2xx code; otherwise throws an error.
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type (not HTTPURLResponse).")
            throw AppError(mastodon: .invalidResponse)
        }

        let statusCode = httpResponse.statusCode
        logger.debug("Response status code: \(statusCode)")

        // If not in the success range, log + throw
        guard (200...299).contains(statusCode) else {
            logFailedResponse(response: httpResponse, data: data)
            throw AppError(mastodon: .serverError(status: statusCode))
        }
    }

    /// Decodes the given data into the provided Decodable type.
    private func decodeResponse<T: Decodable>(_ data: Data, type: T.Type) throws -> T {
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            logDecodingError(error)
            throw error
        }
    }

    /// Reads a value from Keychain for the given key.
    private func loadFromKeychain(key: String) async -> String? {
        do {
            return try await KeychainHelper.shared.read(service: keychainService, account: key)
        } catch {
            logger.error("Failed to load \(key, privacy: .public) from Keychain: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Fetches the saved access token from Keychain.
    private func fetchAccessToken() async -> String? {
        try? await KeychainHelper.shared.read(service: keychainService, account: "accessToken")
    }

    // MARK: - Logging & Error Handling

    /// Logs details about the outgoing request (URL, headers, body).
    private func logRequest(_ request: URLRequest) {
        logger.info("Performing network request to \(request.url?.absoluteString ?? "unknown URL", privacy: .public)")

        if let headers = request.allHTTPHeaderFields {
            logger.debug("Request Headers: \(headers)")
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("Request Body: \(bodyString)")
        }
    }

    /// Logs details about the incoming response (status code, headers, body).
    private func logResponse(_ response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        logger.debug("Received HTTP response with status code: \(httpResponse.statusCode)")
        logger.debug("Response Headers: \(httpResponse.allHeaderFields)")

        if let responseBody = String(data: data, encoding: .utf8) {
            logger.debug("Response Body: \(responseBody)")
        }
    }

    /// Logs details when the server responds with a failure status code, including the body.
    private func logFailedResponse(response: HTTPURLResponse, data: Data) {
        let statusCode = response.statusCode
        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body."
        logger.error("Request failed with status code \(statusCode). Body: \(responseBody)")
    }

    /// Logs details of a decoding error from `JSONDecoder`.
    private func logDecodingError(_ error: Error) {
        guard let decodingError = error as? DecodingError else {
            logger.error("Unknown decoding error: \(error.localizedDescription, privacy: .public)")
            return
        }

        switch decodingError {
        case .dataCorrupted(let context):
            logger.error("Data corrupted: \(context.debugDescription, privacy: .public)")
        case .keyNotFound(let key, let context):
            logger.error("Key '\(key.stringValue, privacy: .public)' not found: \(context.debugDescription, privacy: .public)")
        case .valueNotFound(let value, let context):
            logger.error("Value '\(value)' not found: \(context.debugDescription, privacy: .public)")
        case .typeMismatch(let type, let context):
            logger.error("Type '\(type)' mismatch: \(context.debugDescription, privacy: .public)")
        @unknown default:
            logger.error("Unknown DecodingError occurred.")
        }
    }

    /// Converts a URLError into a more specific `AppError`.
    private func handleURLError(_ urlError: URLError) -> AppError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return AppError(network: .networkError, underlyingError: urlError)
        case .timedOut:
            return AppError(network: .timedOut, underlyingError: urlError)
        default:
            return AppError(network: .requestFailed(underlyingError: urlError), underlyingError: urlError)
        }
    }

    // MARK: - Date Decoding Strategy

    /// Custom date decoding to handle multiple date formats.
    private func dateDecoding(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        // Attempt multiple date formats in descending priority
        if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: dateString)
            ?? ISO8601DateFormatter.standard.date(from: dateString) {
            return date
        }

        // Fallback: yyyy-MM-dd
        if let date = DateFormatter.yyyyMMdd.date(from: dateString) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode date string \(dateString)"
        )
    }
}

// MARK: - JSONDecoder.KeyDecodingStrategy Extension

extension JSONDecoder.KeyDecodingStrategy {
    /// This strategy acts like `.convertFromSnakeCase` in general,
    /// but specifically preserves the top-level "vapid_key" → "vapidKey".
    static var convertSnakeCaseButVapidKey: JSONDecoder.KeyDecodingStrategy {
        .custom { codingKeys in
            guard let lastKey = codingKeys.last else {
                // If no keys, return default
                return codingKeys.last!
            }

            if lastKey.stringValue == "vapid_key" {
                // Hard-map "vapid_key" to "vapidKey"
                return AnyCodingKey(stringValue: "vapidKey")
            } else {
                // Fallback: do typical snake_case → camelCase
                let transformed = snakeCaseToCamelCase(lastKey.stringValue)
                return AnyCodingKey(stringValue: transformed)
            }
        }
    }

    /// Minimal snake_case → camelCase transformation, akin to .convertFromSnakeCase
    private static func snakeCaseToCamelCase(_ original: String) -> String {
        var result = ""
        var makeUpper = false

        for char in original {
            if char == "_" {
                makeUpper = true
            } else if makeUpper {
                result += String(char).uppercased()
                makeUpper = false
            } else {
                result.append(char)
            }
        }
        return result
    }
}

/// A generic CodingKey that can be instantiated from any string.
private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        // We don't use int-based keys in this example
        return nil
    }
}


// MARK: - Helper Extensions

extension ISO8601DateFormatter {
    /// An ISO8601 formatter that supports fractional seconds.
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// A standard ISO8601 formatter (no fractional seconds).
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension DateFormatter {
    /// A formatter for "yyyy-MM-dd" strings.
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

