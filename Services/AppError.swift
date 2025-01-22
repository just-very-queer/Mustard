//
//  AppError.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import Foundation

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
        case network(NetworkError)
        case cache(CacheError)
        case other(String)
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
    
    enum WeatherError: Error {
        case invalidKey
        case invalidURL
        case badResponse
    }
    
    enum NetworkError: Error {
        case invalidURL
        case requestFailed(underlyingError: Error)
        case invalidResponse(statusCode: Int)
        case decodingFailed(underlyingError: Error)
        case timedOut
    }
    
    enum CacheError: Error {
        case noCacheAvailable
        case notFound
        case encodingFailed(underlyingError: Error)
        case decodingFailed(underlyingError: Error)
        case saveFailed(underlyingError: Error)
        case deleteFailed(underlyingError: Error)
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
        self.type = .weather(weather)
        self.underlyingError = underlyingError
    }
    
    init(network: NetworkError, underlyingError: Error? = nil) {
        self.type = .network(network)
        self.underlyingError = underlyingError
    }
    
    init(cache: CacheError, underlyingError: Error? = nil) {
        self.type = .cache(cache)
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
        case .weather(let weatherError):
            return describeWeatherError(weatherError)
        case .network(let networkError):
            return describeNetworkError(networkError)
        case .cache(let cacheError):
            return describeCacheError(cacheError)
        case .other(let msg):
            return msg
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
        case .rateLimitExceeded:
            return "Rate Limit Exceeded"
        case .missingOrClearedCredentials:
            return "Missing or cleared credentials."
        case .cacheNotFound:
            return "Cache not found."
        case .noCacheAvailable:
            return "No cache available."
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
    
    private func describeWeatherError(_ error: WeatherError) -> String {
        switch error {
        case .invalidKey:
            return "Invalid API key."
        case .invalidURL:
            return "Invalid URL."
        case .badResponse:
            return "Bad response from weather service."
        }
    }
    
    private func describeNetworkError(_ error: NetworkError) -> String {
        switch error {
        case .invalidURL:
            return "Invalid URL."
        case .requestFailed(let underlyingError):
            return "Request failed: \(underlyingError.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "Invalid response with status code \(statusCode)."
        case .decodingFailed(let underlyingError):
            return "Decoding failed: \(underlyingError.localizedDescription)"
        case .timedOut:
            return "Request timed out."
        }
    }
    
    private func describeCacheError(_ error: CacheError) -> String {
        switch error {
        case .noCacheAvailable:
            return "No cache available."
        case .notFound:
            return "Cache not found."
        case .encodingFailed(let underlyingError):
            return "Encoding failed: \(underlyingError.localizedDescription)"
        case .decodingFailed(let underlyingError):
            return "Decoding failed: \(underlyingError.localizedDescription)"
        case .saveFailed(let underlyingError):
            return "Failed to save cache: \(underlyingError.localizedDescription)"
        case .deleteFailed(let underlyingError):
            return "Failed to delete cache: \(underlyingError.localizedDescription)"
        }
    }
    
    
    var isRecoverable: Bool {
           switch type {
           case .generic, .authentication, .weather, .other:
               return true
           case .mastodon(let error):
               switch error {
               case .missingCredentials, .networkError, .cacheNotFound:
                   return true
               default:
                   return false
               }
           case .network(let error):
               switch error {
               case .requestFailed, .timedOut:
                   return true // Network issues are often recoverable
               default:
                   return false
               }
           case .cache(let error):
               switch error {
               case .noCacheAvailable, .notFound:
                   return true // Cache misses are recoverable
               default:
                   return false // Other cache errors might not be recoverable
               }
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
               case .missingOrClearedCredentials:
                   return "Credentials are missing or have been cleared. Please re-enter your credentials."
               case .cacheNotFound:
                   return "Cache data not found. Trying to fetch from network."
               case .noCacheAvailable:
                   return "Cache data not available. Trying to fetch from network."
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
                   return "An unexpected authentication error occurred."
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
           case .network(let error):
               switch error {
               case .invalidURL:
                   return "The URL is invalid. Please check the URL and try again."
               case .requestFailed:
                   return "The network request failed. Please check your connection and try again."
               case .invalidResponse:
                   return "Received an invalid response from the server. Please try again later."
               case .decodingFailed:
                   return "Failed to decode the server's response. Please try again later."
               case .timedOut:
                   return "The request timed out. Please check your network connection and try again."
               }
           case .cache(let error):
               switch error {
               case .noCacheAvailable:
                   return "Cache is not available. Try refreshing the data."
               case .notFound:
                   return "Requested data not found in cache. Try fetching it again."
               case .encodingFailed:
                   return "Failed to encode data for caching. Check the data format and try again."
               case .decodingFailed:
                   return "Failed to decode data from cache. Try refreshing the data."
               case .saveFailed:
                   return "Failed to save data to cache. Check storage availability and permissions."
               case .deleteFailed:
                   return "Failed to delete data from cache. Check permissions and try again."
               }
           case .other(let msg):
               return "An error occurred: \(msg). Please try again."
           }
    }
}
