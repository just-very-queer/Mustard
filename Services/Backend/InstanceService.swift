//
//  InstanceService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 27/01/25.
//

import Foundation
import OSLog
import SwiftData

struct Instance: Identifiable, Decodable {
    let id: String
    let name: String
    let addedAt: String?
    let updatedAt: String?
    let checkedAt: String?
    let uptime: Int?
    let up: Bool?
    let dead: Bool?
    let version: String?
    let ipv6: Bool?
    let httpsScore: Int?
    let httpsRank: String?
    let obsScore: Int?
    let obsRank: String?
    let users: String?
    let statuses: String?
    let connections: String?
    let openRegistrations: Bool?
    let info: InstanceInformation?
    let thumbnail: String?
    let thumbnailProxy: String?
    let activeUsers: Int?
    let email: String?
    let admin: String?
    let instanceDescription: String?

    enum CodingKeys: String, CodingKey {
        case id, name, addedAt, updatedAt, checkedAt, uptime, up, dead, version, ipv6, httpsScore, httpsRank, obsScore, obsRank, users, statuses, connections, openRegistrations, info, thumbnail, thumbnailProxy, activeUsers, email, admin
        case instanceDescription = "description"
    }
}

struct InstanceInformation: Decodable {
    let shortDescription: String?
    let fullDescription: String?
    let topic: String?
    let languages: [String]?
    let otherLanguagesAccepted: Bool?
    let federatesWith: String?
    let prohibitedContent: [String]?
    let categories: [String]?
    let title: String?
    let thumbnail: URL?

    enum CodingKeys: String, CodingKey {
        case shortDescription = "short_description"
        case fullDescription = "full_description"
        case topic, languages
        case otherLanguagesAccepted = "other_languages_accepted"
        case federatesWith = "federates_with"
        case prohibitedContent = "prohibited_content"
        case categories, title, thumbnail
    }
}

struct InstanceList: Decodable {
    let instances: [Instance]
}

actor InstanceService {
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "InstanceService")
    private let apiToken = "rjObTn4skTPHA9PZ31VhhIrfjkyF41zAOz0GOV45wEAvtatzAASKPeeQL19ehycdJ0GQci0OeVPtKuFVO5JPU7TPYTjmZNwliSSdAQY7DrARvyqhNQxPqQ24FCPEMZIA"

    // Define a hashable cache key
    private struct CacheKey: Hashable {
        let count: Int
        let sortBy: String
        let sortOrder: String
    }

    // Cache instances in memory
    private var instanceCache: [CacheKey: [Instance]] = [:]

    func fetchInstances(count: Int = 5, sortBy: String = "active_users", sortOrder: String = "desc") async throws -> [Instance] {
        let cacheKey = CacheKey(count: count, sortBy: sortBy, sortOrder: sortOrder)

        // Check the in-memory cache first
        if let cachedInstances = instanceCache[cacheKey] {
            logger.debug("Returning instances from in-memory cache for count: \(count), sortBy: \(sortBy), sortOrder: \(sortOrder)")
            return cachedInstances
        }

        // Construct the URL
        guard let url = URL(string: "https://instances.social/api/1.0/instances/list?count=\(count)&sort_by=\(sortBy)&sort_order=\(sortOrder)") else {
            logger.error("Invalid URL constructed for fetchInstances")
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        // Perform the network request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("Failed to fetch instances. Status code: \(statusCode)")
            throw URLError(.badServerResponse)
        }

        // Log the raw JSON response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            logger.debug("Raw JSON response: \(jsonString)")
        }

        // Decode the response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let instanceList = try decoder.decode(InstanceList.self, from: data)

        // Store in the in-memory cache
        instanceCache[cacheKey] = instanceList.instances
        logger.debug("Cached instances for count: \(count), sortBy: \(sortBy), sortOrder: \(sortOrder)")
        return instanceList.instances
    }

    func fetchMoreInstances(from id: String, count: Int = 20) async throws -> [Instance] {
        guard let url = URL(string: "https://instances.social/api/1.0/instances/list?min_id=\(id)&count=\(count)&language=en&sort_by=active_users&sort_order=desc") else {
            logger.error("Invalid URL constructed for fetchMoreInstances")
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("Failed to fetch more instances. Status code: \(statusCode)")
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let instanceList = try decoder.decode(InstanceList.self, from: data)
        return instanceList.instances
    }

    func fetchInstanceInfo(url: URL) async throws -> Instance {
        let apiURL = url.appendingPathComponent("/api/v1/instance")
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.error("fetchInstanceInfo failed with status code: \(statusCode)")
            throw URLError(.badServerResponse)
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            logger.debug("Raw JSON response for single instance: \(jsonString)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Instance.self, from: data)
    }
}
