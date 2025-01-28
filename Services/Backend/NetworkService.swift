//
//  NetworkService.swift
//  Mustard
//
//  Created by Your Name on 24/01/25.
//  Updated to rely on .convertFromSnakeCase for all responses.
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
    private let keychainService = "MustardKeychain"

    /// A single JSONDecoder that relies on .convertFromSnakeCase for all decoding.
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // If you need any custom date decoding, you can uncomment or modify:
        // decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// A JSONEncoder for any outgoing JSON. Usually you only need .convertToSnakeCase for Mastodon form-params or debugging.
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // MARK: - Initialization
    private init() {
        // Private init to enforce singleton usage
    }

    // MARK: - Public API

    /// Performs a GET (or other method) request for `url` and decodes the result into type `T`.
    /// - Throws: `AppError` if the user is missing credentials or a network/decoding error occurs.
    func fetchData<T: Decodable>(
        url: URL,
        method: String = "GET",
        type: T.Type
    ) async throws -> T {
        // For typical Mastodon endpoints, an access token is required.
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }

        // Debug: Log the baseURL being used (from Keychain).
        let baseURL = try? await KeychainHelper.shared.read(service: keychainService, account: "baseURL")
        logger.debug("Using baseURL: \(baseURL ?? "nil")")

        // Build the request.
        let request = try buildRequest(url: url, method: method, accessToken: accessToken)

        // Perform & decode
        return try await performRequest(request, responseType: T.self)
    }

    /// Performs a POST request to an endpoint with a given body, optionally requiring auth.
    /// - Parameters:
    ///   - endpoint: Relative path (e.g. "/api/v1/apps").
    ///   - body: A dictionary representing the form or JSON body to send.
    ///   - responseType: The decodable model to parse from the server response.
    ///   - baseURLOverride: If non-nil, uses this URL as the base for the endpoint instead of Keychain's baseURL.
    ///   - contentType: Either "application/json" or "application/x-www-form-urlencoded".
    ///   - requireAuth: Whether to attach an existing access token from Keychain.
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

        // Determine the full URL from the endpoint
        let url = try await endpointURL(endpoint, baseURLOverride: baseURLOverride)

        // Build the request with the specified body & content type
        var request = try buildRequest(
            url: url,
            method: "POST",
            body: body,
            contentType: contentType,
            accessToken: accessToken
        )
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        // Perform & decode
        return try await performRequest(request, responseType: T.self)
    }

    /// Performs a simple POST action (with no required return decoding).
    /// E.g. Liking or reblogging a post. Expects 2xx to confirm success.
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

        // Perform the request & ignore the decoded result
        _ = try await performRequest(request, responseType: Data.self)
    }

    /// Registers the app with a Mastodon instance to obtain OAuth client credentials.
    /// - Returns: An `OAuthConfig` containing the clientId, clientSecret, redirectUri, etc.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        let body: [String: String] = [
            "client_name": "Mustard",
            "redirect_uris": "mustard://oauth-callback",
            "scopes": "read write follow push",
            "website": "https://example.com"
        ]

        let endpointURL = instanceURL.appendingPathComponent("/api/v1/apps")
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to serialize request body: \(error.localizedDescription)")
            throw AppError(mastodon: .encodingError, underlyingError: error)
        }

        logger.info("Sending OAuth app registration request to \(endpointURL.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type received (not HTTPURLResponse).")
            throw AppError(mastodon: .invalidResponse)
        }

        logger.debug("Received status code: \(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            logger.error("Registration failed: HTTP \(httpResponse.statusCode), body: \(responseBody)")
            throw AppError(mastodon: .serverError(status: httpResponse.statusCode))
        }

        // Decode with .convertFromSnakeCase (our shared decoder)
        do {
            let registerResponse = try jsonDecoder.decode(RegisterResponse.self, from: data)
            logger.info("Successfully registered OAuth app. Client ID: \(registerResponse.clientId)")

            // Construct & return the OAuthConfig
            return OAuthConfig(
                clientId: registerResponse.clientId,
                clientSecret: registerResponse.clientSecret,
                redirectUri: registerResponse.redirectUri,
                scope: "read write follow push"
            )
        } catch {
            logger.error("Failed to decode RegisterResponse: \(error.localizedDescription)")
            if let responseBody = String(data: data, encoding: .utf8) {
                logger.debug("Response body: \(responseBody)")
            }
            throw AppError(mastodon: .decodingError, underlyingError: error)
        }
    }

    /// Exchanges the authorization code for an access token with the Mastodon instance.
    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws {
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "redirect_uri": config.redirectUri,
            "scope": config.scope
        ]

        // Use form-urlencoded for the token exchange request
        let tokenResponse: TokenResponse = try await postData(
            endpoint: "/oauth/token",
            body: body,
            responseType: TokenResponse.self,
            baseURLOverride: instanceURL,
            contentType: "application/x-www-form-urlencoded",
            requireAuth: false
        )

        // Save the new access token in Keychain
        try await KeychainHelper.shared.save(
            tokenResponse.accessToken,
            service: keychainService,
            account: "accessToken"
        )

        logger.info("Exchanged authorization code for an access token.")
    }

    /// Fetches the currently authenticated user's profile via `/api/v1/accounts/verify_credentials`.
    func fetchCurrentUser(
        instanceURL: URL? = nil
    ) async throws -> User {
        let url: URL
        if let customURL = instanceURL {
            url = customURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        } else {
            guard let baseURLString = await loadFromKeychain(key: "baseURL"),
                  let base = URL(string: baseURLString) else {
                throw AppError(mastodon: .missingCredentials)
            }
            url = base.appendingPathComponent("/api/v1/accounts/verify_credentials")
        }

        // Reuse our fetchData function
        let user: User = try await fetchData(url: url, method: "GET", type: User.self)
        logger.info("Successfully fetched current user: \(user.username, privacy: .public)")
        return user
    }

    /// Constructs a full URL from a path and optional override base URL.
    /// If no override is given, it reads the baseURL from Keychain.
    func endpointURL(
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

    // MARK: - Private Methods

    /// Performs the actual network request with rate-limiting, logs, validates, and decodes the response.
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        // Rate limiting
        guard await rateLimiter.tryConsume() else {
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }

        do {
            logRequest(request)
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data)

            try validateResponse(response, data: data)
            return try jsonDecoder.decode(T.self, from: data)

        } catch let urlError as URLError {
            logger.error("URLError: \(urlError.localizedDescription)")
            throw handleURLError(urlError)
        } catch let decodingError as DecodingError {
            logDecodingError(decodingError)
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)
        } catch {
            logger.error("Unknown error: \(error.localizedDescription)")
            throw AppError(type: .other("Unknown network error"), underlyingError: error)
        }
    }

    /// Builds a URLRequest with optional body & Bearer token.
    private func buildRequest(
        url: URL,
        method: String,
        body: [String: String]? = nil,
        contentType: String = "application/json",
        accessToken: String? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method

        // Attach bearer token if provided
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body if present
        if let formBody = body {
            switch contentType.lowercased() {
            case "application/json":
                request.httpBody = try JSONSerialization.data(withJSONObject: formBody)
            case "application/x-www-form-urlencoded":
                let formString = formBody
                    .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                    .joined(separator: "&")
                request.httpBody = formString.data(using: .utf8)
            default:
                throw AppError(message: "Unsupported content type: \(contentType)")
            }
        }

        return request
    }

    /// Validates the HTTP response status code (must be 2xx).
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type (not HTTPURLResponse).")
            throw AppError(mastodon: .invalidResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logFailedResponse(response: httpResponse, data: data)
            throw AppError(mastodon: .serverError(status: httpResponse.statusCode))
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

    private func logRequest(_ request: URLRequest) {
        logger.info("Request → \(request.url?.absoluteString ?? "Unknown URL") [\(request.httpMethod ?? "GET")]")
        if let headers = request.allHTTPHeaderFields {
            logger.debug("Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("Body: \(bodyString)")
        }
    }

    private func logResponse(_ response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        logger.debug("Response ← Status: \(httpResponse.statusCode)")
        logger.debug("Headers: \(httpResponse.allHeaderFields)")
        if let responseBody = String(data: data, encoding: .utf8) {
            logger.debug("Body: \(responseBody)")
        }
    }

    private func logFailedResponse(response: HTTPURLResponse, data: Data) {
        let bodyString = String(data: data, encoding: .utf8) ?? "Unable to decode body."
        logger.error("Server returned status \(response.statusCode). Body: \(bodyString)")
    }

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            logger.error("Data corrupted: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            logger.error("Key '\(key.stringValue)' not found: \(context.debugDescription)")
        case .valueNotFound(let value, let context):
            logger.error("Value '\(value)' not found: \(context.debugDescription)")
        case .typeMismatch(let type, let context):
            logger.error("Type mismatch '\(type)': \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown DecodingError occurred.")
        }
    }

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
}

