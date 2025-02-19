//
//  SearchService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import Foundation
import Combine

class SearchService {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func search(query: String, type: String? = nil, limit: Int = 20, resolve: Bool = false, excludeUnreviewed: Bool = false) async throws -> SearchResults {
        var queryItems = [URLQueryItem(name: "q", value: query)]

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "resolve", value: String(resolve)))
        queryItems.append(URLQueryItem(name: "exclude_unreviewed", value: String(excludeUnreviewed)))
        
        // Construct URL using NetworkService's helper
        let url = try await networkService.endpointURL("/api/v2/search", queryItems: queryItems)
        
        return try await networkService.fetchData(url: url, method: "GET", type: SearchResults.self)
    }

    func fetchTrendingHashtags() async throws -> [Tag] {
        let url = try await networkService.endpointURL("/api/v1/trends/tags")
        return try await networkService.fetchData(url: url, method: "GET", type: [Tag].self)
    }
}


struct TagHistory: Decodable {
     var day: String
     var uses: String
     var accounts: String
 }
