//
//  ServicesAndErrorManagement.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import Foundation
import SwiftUI
import OSLog
import CoreLocation

// MARK: - Notification.Name Extensions

extension Notification.Name {
    static let didAuthenticate = Notification.Name("didAuthenticate")
    static let authenticationFailed = Notification.Name("authenticationFailed")
    static let didReceiveOAuthCallback = Notification.Name("didReceiveOAuthCallback")
    static let didUpdateLocation = Notification.Name("didUpdateLocation")
    static let didDecodePostLocation = Notification.Name("didDecodePostLocatior")
    static let didRequestWeatherFetch = Notification.Name("didRequestWeatherFetch")
}

// MARK: - AppError

struct AppError: Identifiable, Error {
    let id = UUID()
    let type: ErrorType
    let underlyingError: Error?
    let timestamp: Date = Date()
    
    enum ErrorType {
        case generic(String)
        case mastodon(MastodonError)
        case authentication(AuthenticationError)
        case weather(WeatherError)
    }
    
    enum MastodonError: Equatable {
        case missingCredentials
        case invalidResponse
        case badRequest
        case unauthorized
        case forbidden
        case notFound
        case serverError(status: Int)
        case encodingError
        case decodingError
        case networkError(message: String)
        case oauthError(message: String)
        case unknown(status: Int)
        case failedToFetchTimeline
        case failedToFetchTimelinePage
        case failedToClearTimelineCache
        case failedToLoadTimelineFromDisk
        case failedToSaveTimelineToDisk
        case failedToFetchTrendingPosts
        case invalidToken
        case failedToSaveAccessToken
        case failedToClearAccessToken
        case failedToRetrieveAccessToken
        case failedToRetrieveInstanceURL
        case postNotFound
        case failedToRegisterOAuthApp
        case failedToExchangeCode
        case failedToStreamTimeline
        case invalidAuthorizationCode
        case authError
        case WeatherError
        case rateLimitExceeded
        case missingOrClearedCredentials
        case cacheNotFound
        case noCacheAvailable
        
        
        static func == (lhs: MastodonError, rhs: MastodonError) -> Bool {
            switch (lhs, rhs) {
            case (.missingCredentials, .missingCredentials),
                (.invalidResponse, .invalidResponse),
                (.badRequest, .badRequest),
                (.unauthorized, .unauthorized),
                (.forbidden, .forbidden),
                (.notFound, .notFound),
                (.failedToFetchTimeline, .failedToFetchTimeline),
                (.failedToFetchTimelinePage, .failedToFetchTimelinePage),
                (.failedToClearTimelineCache, .failedToClearTimelineCache),
                (.failedToLoadTimelineFromDisk, .failedToLoadTimelineFromDisk),
                (.failedToSaveTimelineToDisk, .failedToSaveTimelineToDisk),
                (.failedToFetchTrendingPosts, .failedToFetchTrendingPosts),
                (.invalidToken, .invalidToken),
                (.failedToSaveAccessToken, .failedToSaveAccessToken),
                (.failedToClearAccessToken, .failedToClearAccessToken),
                (.failedToRetrieveAccessToken, .failedToRetrieveAccessToken),
                (.failedToRetrieveInstanceURL, .failedToRetrieveInstanceURL),
                (.postNotFound, .postNotFound),
                (.failedToRegisterOAuthApp, .failedToRegisterOAuthApp),
                (.failedToExchangeCode, .failedToExchangeCode),
                (.failedToStreamTimeline, .failedToStreamTimeline),
                (.invalidAuthorizationCode, .invalidAuthorizationCode):
                return true
            case (.serverError(let lhsStatus), .serverError(let rhsStatus)):
                return lhsStatus == rhsStatus
            case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
                return lhsMessage == rhsMessage
            case (.oauthError(let lhsMessage), .oauthError(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    enum AuthenticationError: Equatable {
        case invalidAuthorizationCode
        case webAuthSessionFailed
        case noAuthorizationCode
        case unknown
    }
    
    // WeatherError: Custom error for weather-related issues.
    enum WeatherError: Error {
        case invalidKey
        case invalidURL
        case badResponse
    }
    
    
    // MARK: - Initializers
    init(message: String, underlyingError: Error? = nil) {
        self.type = .generic(message)
        self.underlyingError = underlyingError
    }
    
    init(mastodon: MastodonError, underlyingError: Error? = nil) {
        self.type = .mastodon(mastodon)
        self.underlyingError = underlyingError
    }
    
    init(authentication: AuthenticationError, underlyingError: Error? = nil) {
        self.type = .authentication(authentication)
        self.underlyingError = underlyingError
        
    }
    init(type: ErrorType, underlyingError: Error? = nil) {
        self.type = type
        self.underlyingError = underlyingError
    }
    
    init(weather: WeatherError, underlyingError: Error? = nil) {
        self.type = .mastodon(.WeatherError) // This associates the WeatherError as part of MastodonError
        self.underlyingError = underlyingError
    }
    // MARK: - Computed Properties
    
    var message: String {
        switch type {
        case .generic(let msg):
            return msg
        case .mastodon(let error):
            return describeMastodonError(error)
        case .authentication(let authError):
            return describeAuthenticationError(authError)
        case .weather:
            return "Weather-related error occurred." // Return a string message
        }
    }
    
    private func describeMastodonError(_ error: MastodonError) -> String {
        switch error {
        case .missingCredentials:
            return "Missing base URL or access token."
        case .invalidResponse:
            return "Invalid response from server."
        case .badRequest:
            return "Bad request."
        case .unauthorized:
            return "Unauthorized access."
        case .forbidden:
            return "Forbidden action."
        case .notFound:
            return "Resource not found."
        case .serverError(let status):
            return "Server error with status code \(status)."
        case .encodingError:
            return "Failed to encode data."
        case .decodingError:
            return "Failed to decode data."
        case .networkError(let message):
            return "Network error: \(message)"
        case .oauthError(let message):
            return "OAuth error: \(message)"
        case .unknown(let status):
            return "Unknown error with status code \(status)."
        case .failedToFetchTimeline:
            return "Unable to fetch timeline."
        case .failedToFetchTimelinePage:
            return "Unable to fetch more timeline posts."
        case .failedToClearTimelineCache:
            return "Failed to clear timeline cache."
        case .failedToLoadTimelineFromDisk:
            return "Failed to load timeline from disk."
        case .failedToSaveTimelineToDisk:
            return "Failed to save timeline to disk."
        case .failedToFetchTrendingPosts:
            return "Failed to fetch trending posts."
        case .invalidToken:
            return "Invalid access token."
        case .failedToSaveAccessToken:
            return "Failed to save access token."
        case .failedToClearAccessToken:
            return "Failed to clear access token."
        case .failedToRetrieveAccessToken:
            return "Failed to retrieve access token."
        case .failedToRetrieveInstanceURL:
            return "Failed to retrieve instance URL."
        case .postNotFound:
            return "Post not found."
        case .failedToRegisterOAuthApp:
            return "Failed to register OAuth application."
        case .failedToExchangeCode:
            return "Failed to exchange authorization code."
        case .failedToStreamTimeline:
            return "Failed to stream timeline."
        case .invalidAuthorizationCode:
            return "Invalid authorization code provided."
        case .authError:
            return "Authentication Error"
        case .WeatherError:
            return "Weather-related error occurred."
        case .rateLimitExceeded:
            return "Rate Limit Exceeded"
        case .missingOrClearedCredentials:
            return "missingOrClearedCredentials"
        case .cacheNotFound:
            return "Cached was not saved"
        case .noCacheAvailable:
            return "noCacheAvailable"
        }
    }
    private func describeAuthenticationError(_ error: AuthenticationError) -> String {
        switch error {
            
        case .invalidAuthorizationCode:
            return "Invalid authorization code provided."
        case .webAuthSessionFailed:
            return "Web authentication session failed to start."
        case .noAuthorizationCode:
            return "Authorization code was not received."
        case .unknown:
            return "An unknown authentication error occurred."
        }
    }
    
    var isRecoverable: Bool {
        switch type {
        case .generic:
            return true
        case .mastodon(let error):
            switch error {
            case .missingCredentials:
                return true
            case .networkError:
                return true
            default:
                return false
            }
        case .authentication:
            return true
        case .weather:
            return true // Assuming weather errors are recoverable
        }
    }
    
    var recoverySuggestion: String? {
        switch type {
        case .generic:
            return "Please try again."
        case .mastodon(let error):
            switch error {
            case .missingCredentials:
                return "Please verify your login credentials."
            case .networkError:
                return "Please check your internet connection and try again."
            default:
                return nil
            }
        case .authentication(let authError):
            switch authError {
            case .invalidAuthorizationCode:
                return "Please check your authorization code and try again."
            case .webAuthSessionFailed:
                return "Ensure that web authentication is available and try again."
            case .noAuthorizationCode:
                return "Authorization code was not received. Please try logging in again."
            case .unknown:
                return "An unexpected error occurred during authentication."
            }
        case .weather(let error):
            switch error {
            case .invalidKey:
                return "Please check your weather API key."
            case .invalidURL:
                return "Please check the weather API URL."
            case .badResponse:
                return "Please try again later. If the issue persists, check the API service status."
            }
        }
        
    }
}

