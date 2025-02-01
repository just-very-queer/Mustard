//
//  InstanceService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 27/01/25.
//

import Foundation
import OSLog

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
    
    // Add other properties as needed, based on the JSON response
    // Use CodingKeys if the JSON keys are different from property names

    enum CodingKeys: String, CodingKey {
        case id, name, addedAt, updatedAt, checkedAt, uptime, up, dead, version, ipv6, httpsScore, httpsRank, obsScore, obsRank, users, statuses, connections, openRegistrations, info, thumbnail, thumbnailProxy, activeUsers, email, admin
        case instanceDescription = "description" // map the JSON "description" to instanceDescription
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
        case categories
        case title
        
        case thumbnail
    }
}

// Wrapper to decode the list of instances from the JSON response
struct InstanceList: Decodable {
    let instances: [Instance]
}

struct InstanceService {
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "InstanceService")

    // **WARNING: DO NOT DO THIS IN A PRODUCTION APP**
    // Hardcoding the API token is a security risk.
    // This is only for demonstration and testing.
    private let apiToken = "rjObTn4skTPHA9PZ31VhhIrfjkyF41zAOz0GOV45wEAvtatzAASKPeeQL19ehycdJ0GQci0OeVPtKuFVO5JPU7TPYTjmZNwliSSdAQY7DrARvyqhNQxPqQ24FCPEMZIA"

    func fetchInstances(count: Int = 5) async throws -> [Instance] {
        // Removed language parameter and added default value to the count parameter.
        guard let url = URL(string: "https://instances.social/api/1.0/instances/list?count=\(count)&sort_by=active_users&sort_order=desc") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                logger.error("Failed to fetch instances. Status code: \(statusCode)")
                throw URLError(.badServerResponse)
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Raw JSON response: \(jsonString)")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let instanceList = try decoder.decode(InstanceList.self, from: data)
            return instanceList.instances
        } catch {
            logger.error("Error fetching or decoding instances: \(error.localizedDescription)")
            throw error
        }
    }

    
    func fetchMoreInstances(from id: String, count: Int = 20) async throws -> [Instance] {
        guard let url = URL(string: "https://instances.social/api/1.0/instances/list?min_id=\(id)&count=\(count)&language=en&sort_by=active_users&sort_order=desc") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                logger.error("Failed to fetch more instances. Status code: \(statusCode)")
                throw URLError(.badServerResponse)
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Raw JSON response for more instances: \(jsonString)")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let instanceList = try decoder.decode(InstanceList.self, from: data)
            return instanceList.instances
        } catch {
            logger.error("Error fetching or decoding more instances: \(error.localizedDescription)")
            throw error
        }
    }
}
