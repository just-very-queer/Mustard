//
//  MastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

class MastodonService {
    static let shared = MastodonService()
    private let baseURL = URL(string: "https://mastodon.social/api/v1/")!

    private var accessToken: String? {
        // Retrieve the access token from secure storage (e.g., Keychain)
        return "YOUR_ACCESS_TOKEN"
    }

    private func createRequest(endpoint: String, method: String = "GET") -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func fetchHomeTimeline(completion: @escaping (Result<[Post], Error>) -> Void) {
        let request = createRequest(endpoint: "timelines/home")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "Mustard", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received."])))
                return
            }

            do {
                let postsData = try JSONDecoder().decode([PostData].self, from: data)
                let posts = postsData.map { $0.toPost() }
                completion(.success(posts))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Add other API methods as needed
}

