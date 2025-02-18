//
//  NetworkService.swift
//  Mustard
//
//  Created by Your Name on 24/01/25.
//  Updated to rely on .convertFromSnakeCase for all responses and fixed DateFormatter typo.
//
//

import Foundation
import OSLog
import SwiftUI
import CoreLocation

/// A service responsible for all network requests in the Mustard app, including
/// Mastodon API calls, OAuth flows, and general fetch/post actions.
public class NetworkService {
    // MARK: - Singleton Instance
    
    /// Shared singleton instance of `NetworkService`.
    public static let shared = NetworkService()
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "NetworkService")
    private let rateLimiter = RateLimiter(capacity: 40, refillRate: 1.0) // 40 requests per second
    private let keychainService = "MustardKeychain"
    
    /// JSONDecoder configured with `.convertFromSnakeCase` and appropriate date decoding strategies.
    let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase  // This is the key fix!
        decoder.dateDecodingStrategy = .custom { decoder in  // More robust date handling
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            //Handle the case of date with no fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from:dateString){
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid date format: \(dateString)")
        }
        return decoder
    }()
    
    // Inside NetworkService, add this for consistent date formatting:
    static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]  //.withFractionalSeconds is crucial
        return formatter
    }()
    
    /// JSONEncoder configured with `.convertToSnakeCase` and ISO8601 date encoding.
    let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    // MARK: - Token Management
    
    /// Stores the date and time when the access token was created.
    /// This can be used for token expiration and refresh logic.
    private var tokenCreationDate: Date?
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern.
    public init() {
        // Additional setup if needed
    }
    
    // MARK: - Public API
    
    /// Performs a GET (or other HTTP method) request to the specified URL and decodes the response into type `T`.
    ///
    /// - Parameters:
    ///   - url: The endpoint URL.
    ///   - method: HTTP method (e.g., "GET", "POST"). Defaults to "GET".
    ///   - type: The expected Decodable type of the response.
    /// - Returns: Decoded response of type `T`.
    /// - Throws: `AppError` if the user is missing credentials, rate limit is exceeded, or a network/decoding error occurs.
    func fetchData<T: Decodable>(
        url: URL,
        method: String = "GET",
        type: T.Type
    ) async throws -> T {
        // Ensure rate limiting
        guard await rateLimiter.tryConsume() else {
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }
        
        // Retrieve access token from Keychain
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }
        
        // Debug: Log the baseURL being used (from Keychain)
        if let baseURLString = try? await KeychainHelper.shared.read(service: keychainService, account: "baseURL") {
            logger.debug("Using baseURL: \(baseURLString)")
        } else {
            logger.warning("Base URL not found in Keychain.")
        }
        
        // Build the URLRequest
        let request = try buildRequest(url: url, method: method, accessToken: accessToken)
        
        // Perform the network request and decode the response
        return try await performRequest(request: request, responseType: type)
    }
    
    /// Performs a POST request to the specified endpoint with a given body, optionally overriding the base URL.
    ///
    /// - Parameters:
    ///   - endpoint: Relative path (e.g., "/api/v1/apps").
    ///   - body: Dictionary representing the form or JSON body to send.
    ///   - responseType: The expected Decodable type of the response.
    ///   - baseURLOverride: Optional URL to override the base URL from Keychain.
    ///   - contentType: Content type of the request body. Defaults to "application/json".
    /// - Returns: Decoded response of type `T`.
    /// - Throws: `AppError` if a network/decoding error occurs.
    
    func postData<T: Decodable>(
        endpoint: String,
        body: [String: String],
        responseType: T.Type,
        baseURLOverride: URL? = nil,
        contentType: String = "application/json"
    ) async throws -> T {
        // Ensure rate limiting
        guard await rateLimiter.tryConsume() else {
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }
        
        // Retrieve access token from Keychain
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }
        
        // Construct the full URL
        let url = try await endpointURL(endpoint, baseURLOverride: baseURLOverride)
        
        // Build the URLRequest with the specified body and content type
        var request = try buildRequest(url: url, method: "POST", body: body, contentType: contentType, accessToken: accessToken)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        // Perform the network request and decode the response
        return try await performRequest(request: request, responseType: responseType)
    }
    
    
    /// Generic request function to perform API calls and decode responses.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint path (e.g., "/api/v1/timelines/home").
    ///   - method: HTTP method for the request (e.g., .get, .post).
    ///   - responseType: The expected Decodable type for the response.
    /// - Returns: Decoded response of type `T`.
    /// - Throws: `AppError` if request fails, rate limit is exceeded, or decoding fails.
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        responseType: T.Type
    ) async throws -> T {
        // Ensure rate limiting
        guard await rateLimiter.tryConsume() else {
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }
        
        // Retrieve access token from Keychain
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }
        
        // Construct the full URL
        let url = try await endpointURL(endpoint)
        
        // Build the URLRequest
        let request = try buildRequest(url: url, method: method.rawValue, accessToken: accessToken)
        
        // Perform the network request and decode the response
        return try await performRequest(request: request, responseType: responseType)
    }
    
    /// Performs a POST action (e.g., liking or reblogging a post) without expecting a decoded response.
    ///
    /// - Parameters:
    ///   - postID: The ID of the post to perform the action on.
    ///   - path: The API path for the action (e.g., "/api/v1/statuses/{id}/favourite").
    ///   - baseURLOverride: Optional URL to override the base URL from Keychain.
    /// - Throws: `AppError` if a network error occurs.
    func postAction(for postID: String, path: String, baseURLOverride: URL? = nil) async throws {
        // Ensure rate limiting
        guard await rateLimiter.tryConsume() else {
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }
        
        // Retrieve access token from Keychain
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }
        
        // Construct the full URL
        let url = try await endpointURL(path, baseURLOverride: baseURLOverride)
        
        // Build the URLRequest
        let request = try buildRequest(url: url, method: "POST", accessToken: accessToken)
        
        // Perform the network request without expecting a decoded response
        _ = try await performRequest(request: request, responseType: Data.self)
    }
    
    /// Fetches timeline posts with pagination support.
    ///
    /// - Parameters:
    ///   - page: The page number to fetch. Page 1 fetches the latest posts, subsequent pages fetch older posts.
    /// - Returns: An array of `Post` objects.
    /// - Throws: `AppError` if the request fails.
    func fetchTimelinePosts(page: Int) async throws -> [Post] {
        var endpoint = "/api/v1/timelines/home"

        if page > 1 {
            // Fetch older posts by appending `max_id` to the request
            if let lastPostID = try? await fetchLastPostID() {
                endpoint += "?max_id=\(lastPostID)"
            }
        }

        do {
            return try await request(endpoint: endpoint, method: .get, responseType: [Post].self)
        } catch {
            logger.error("Failed to fetch timeline posts (Page \(page)): \(error.localizedDescription)")
            throw error
        }
    }

    /// Retrieves the ID of the last post in the timeline for pagination.
    ///
    /// - Returns: The `id` of the last post if available.
    /// - Throws: `AppError` if fetching fails.
    private func fetchLastPostID() async throws -> String? {
        let timelinePosts: [Post] = try await request(endpoint: "/api/v1/timelines/home", method: .get, responseType: [Post].self)
        return timelinePosts.last?.id
    }

    // MARK: - OAuth Flow
    
    /// Registers the app with the specified Mastodon instance to obtain OAuth client credentials.
    ///
    /// - Parameter instanceURL: The base URL of the Mastodon instance.
    /// - Returns: An `OAuthConfig` containing the client ID, client secret, redirect URI, and scope.
    /// - Throws: `AppError` if registration fails or decoding the response fails.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        let body: [String: String] = [
            "client_name": "Mustard",
            "redirect_uris": "mustard://oauth-callback",
            "scopes": "read write follow push",
            "website": "https://example.com" // Replace with your app's website
        ]
        
        let endpointURL = instanceURL.appendingPathComponent("/api/v1/apps")
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Serialize the request body to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to serialize request body: \(error.localizedDescription)")
            throw AppError(mastodon: .encodingError, underlyingError: error)
        }
        
        logger.info("Sending OAuth app registration request to \(endpointURL.absoluteString)")
        
        // Perform the network request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate the HTTP response
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
        
        // Decode the response using the shared JSONDecoder
        do {
            let registerResponse = try jsonDecoder.decode(RegisterResponse.self, from: data)
            logger.info("Successfully registered OAuth app. Client ID: \(registerResponse.clientId)")
            
            // Return the OAuth configuration
            return OAuthConfig(
                clientId: registerResponse.clientId,
                clientSecret: registerResponse.clientSecret,
                redirectUri: registerResponse.redirectUri,
                scope: "read write follow push"
            )
        } catch {
            logger.error("Failed to decode RegisterResponse: \(error.localizedDescription)")
            if let responseBody = String(data: data, encoding: .utf8) {
                logger.debug("Response body for debugging: \(responseBody)")
            }
            throw AppError(mastodon: .decodingError, underlyingError: error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Constructs a full URL from a path and optional override base URL.
    ///
    /// - Parameters:
    ///   - path: The API path (e.g., "/api/v1/apps").
    ///   - baseURLOverride: Optional URL to override the base URL from Keychain.
    /// - Returns: A fully constructed `URL`.
    /// - Throws: `AppError` if the base URL is missing or invalid.
    func endpointURL(_ path: String, baseURLOverride: URL? = nil) async throws -> URL {
        if let override = baseURLOverride {
            return override.appendingPathComponent(path)
        }
        guard let baseURLString = await loadFromKeychain(key: "baseURL"),
              let baseURL = URL(string: baseURLString) else {
            throw AppError(mastodon: .missingCredentials)
        }
        return baseURL.appendingPathComponent(path)
    }
    
    /// Builds a `URLRequest` with optional body and Bearer token.
    ///
    /// - Parameters:
    ///   - url: The endpoint URL.
    ///   - method: HTTP method (e.g., "GET", "POST").
    ///   - body: Optional body parameters.
    ///   - contentType: Content type of the request body.
    ///   - accessToken: Optional Bearer token for authorization.
    /// - Returns: A configured `URLRequest`.
    /// - Throws: `AppError` if the content type is unsupported.
    private func buildRequest(
        url: URL,
        method: String,
        body: [String: String]? = nil,
        contentType: String = "application/json",
        accessToken: String? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Attach Bearer token if provided
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            logger.debug("Authorization Header set with Bearer token.")
        } else {
            logger.debug("No Authorization Header set.")
        }
        
        // Encode the body based on content type
        if let body = body {
            switch contentType.lowercased() {
            case "application/json":
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
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
    
    /// Performs the actual network request, logs details, validates the response, and decodes it.
    ///
    /// - Parameters:
    ///   - request: The `URLRequest` to perform.
    ///   - responseType: The expected Decodable type of the response.
    /// - Returns: Decoded response of type `T`.
    /// - Throws: `AppError` if a network or decoding error occurs.
    private func performRequest<T: Decodable>(
        request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        do {
            // Log the request details
            logRequest(request)
            
            // Perform the network request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response details
            logResponse(response, data: data)
            
            // Validate the HTTP response
            try validateResponse(response, data: data)
            
            // Attempt to decode the response
            return try jsonDecoder.decode(T.self, from: data)
            
        } catch let urlError as URLError {
            logger.error("Network request failed with URLError: \(urlError.localizedDescription)")
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw AppError(network: .networkError, underlyingError: urlError)
            case .timedOut:
                throw AppError(network: .timedOut, underlyingError: urlError)
            default:
                throw AppError(network: .requestFailed(underlyingError: urlError), underlyingError: urlError)
            }
        } catch let decodingError as DecodingError {
            logDecodingError(decodingError)
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)
        } catch let appError as AppError {
            throw appError
        } catch {
            logger.error("Network request failed with unknown error: \(error.localizedDescription)")
            throw AppError(type: .other("Unknown network error"), underlyingError: error)
        }
    }
    
    /// Fetches the access token from Keychain.
    ///
    /// - Returns: The access token string if available.
    func fetchAccessToken() async -> String? {
        do {
            return try await KeychainHelper.shared.read(service: keychainService, account: "accessToken")
        } catch {
            logger.error("Failed to fetch access token from Keychain: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Response Validation
    
    /// Validates the HTTP response status code (must be 2xx).
    ///
    /// - Parameters:
    ///   - response: The `URLResponse` received.
    ///   - data: The response data.
    /// - Throws: `AppError` if the status code is not within the 2xx range.
    func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type received (not HTTPURLResponse).")
            throw AppError(mastodon: .invalidResponse)
        }
        
        logger.debug("Received HTTP response with status code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            logFailedResponse(response: httpResponse, data: data)
            throw AppError(mastodon: .serverError(status: httpResponse.statusCode))
        }
    }
    
    /// Fetches the currently authenticated user's profile via `/api/v1/accounts/verify_credentials`.
    ///
    /// - Parameter instanceURL: Optional URL to override the base URL from Keychain.
    /// - Returns: A `User` object representing the current user.
    /// - Throws: `AppError` if fetching the user fails.
    func fetchCurrentUser(instanceURL: URL? = nil) async throws -> User {
        // Retrieve the access token from Keychain
        guard let accessToken = try await KeychainHelper.shared.read(service: keychainService, account: "accessToken") else {
            throw AppError(mastodon: .missingCredentials)
        }
        logger.debug("Access token: \(String(describing: accessToken))") // Log for debugging
        
        // Determine the correct URL to fetch the current user's profile
        let userFetchURL: URL
        if let customURL = instanceURL {
            userFetchURL = customURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        } else {
            guard let baseURLString = try await KeychainHelper.shared.read(service: keychainService, account: "baseURL"),
                  let baseURL = URL(string: baseURLString) else {
                throw AppError(mastodon: .missingCredentials)
            }
            userFetchURL = baseURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        }
        
        // Build the request and set the Authorization header
        var request = URLRequest(url: userFetchURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Reuse fetchData method to get the current user details
        let user: User = try await fetchData(url: userFetchURL, method: "GET", type: User.self)
        logger.info("Successfully fetched current user: \(user.username, privacy: .public)")
        return user
    }
    
    // MARK: - Logging Methods
    
    /// Logs the details of a `URLRequest`.
    ///
    /// - Parameter request: The `URLRequest` to log.
    func logRequest(_ request: URLRequest) {
        logger.info("Request → \(request.url?.absoluteString ?? "Unknown URL") [\(request.httpMethod ?? "GET")]")
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logger.debug("Request Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("Request Body: \(bodyString)")
        }
    }
    
    /// Logs the details of a `URLResponse`.
    ///
    /// - Parameters:
    ///   - response: The `URLResponse` to log.
    ///   - data: The response data.
    private func logResponse(_ response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        logger.debug("Response ← Status: \(httpResponse.statusCode)")
        logger.debug("Response Headers: \(httpResponse.allHeaderFields)")
        if let responseBody = String(data: data, encoding: .utf8) {
            logger.debug("Response Body: \(responseBody)")
        }
    }
    
    /// Logs failed HTTP responses with status codes outside the 2xx range.
    ///
    /// - Parameters:
    ///   - response: The `HTTPURLResponse` received.
    ///   - data: The response data.
    private func logFailedResponse(response: HTTPURLResponse, data: Data) {
        let bodyString = String(data: data, encoding: .utf8) ?? "Unable to decode response body."
        logger.error("Server returned status \(response.statusCode). Body: \(bodyString)")
    }
    
    /// Logs detailed information about a `DecodingError`.
    ///
    /// - Parameter error: The `DecodingError` to log.
    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            logger.error("Data corrupted: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            logger.error("Key '\(key.stringValue)' not found: \(context.debugDescription)")
        case .valueNotFound(let value, let context):
            logger.error("Value of type '\(value)' not found: \(context.debugDescription)")
        case .typeMismatch(let type, let context):
            logger.error("Type '\(type)' mismatch: \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown DecodingError occurred.")
        }
    }
    
    // MARK: - Keychain Helpers
    
    /// Loads a value from Keychain for the given key.
    ///
    /// - Parameter key: The key to look up in Keychain.
    /// - Returns: The value as a `String` if found.
    private func loadFromKeychain(key: String) async -> String? {
        do {
            return try await KeychainHelper.shared.read(service: keychainService, account: key)
        } catch {
            logger.error("Failed to load \(key, privacy: .public) from Keychain: \(error.localizedDescription)")
            return nil
        }
    }
}


enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
