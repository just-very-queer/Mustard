//
//  SearchModels.swift
//  Mustard
//
//  Created by Jules on 30/07/25.
//

import Foundation

// MARK: - Search-specific Models and Enums

struct SearchResults: Decodable {
    var accounts: [Account] = []
    var statuses: [Post] = []
    var hashtags: [Tag] = []
}

enum SearchCategory: String, CaseIterable, Identifiable {
    case all = "All", accounts = "Accounts", posts = "Posts", hashtags = "Hashtags", trending = "Trending"
    var id: String { self.rawValue }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case day = "1 Day", week = "7 Days", month = "1 Month", year = "1 Year"
    var id: String { self.rawValue }
}

struct IdentifiableError: Identifiable, Error {
    let id = UUID()
    let message: String
    var localizedDescription: String { message }
}

struct SearchFilters {
    var limit: Int? = 20
    var resolve: Bool? = true
    var excludeUnreviewed: Bool? = false
    var accountId: String? = nil
    var maxId: String? = nil
    var minId: String? = nil
    var offset: Int? = nil
}
