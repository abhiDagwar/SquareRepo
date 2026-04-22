//
//  RepositoryService.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import Foundation

// MARK: EndPoint
private enum SquareGitHubAPI {
    static let baseURL = "https://api.github.com"

    static func squareReposURL(page: Int, perPage: Int) -> URL? {
        var components = URLComponents(string: "\(baseURL)/orgs/square/repos")
        components?.queryItems = [
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return components?.url
    }
}

// MARK: Protocol
protocol RepositoryServiceProtocol {
    func fetchRepositories(page: Int, perPage: Int) async throws -> [Repository]
}


// MARK: API Implementation
class GitHubRepositoryService: RepositoryServiceProtocol {
    
    // MARK: Dependencies
    private let session: URLSession
    private let decoder: JSONDecoder
    
    // MARK: Init
    init(session: URLSession = .shared, decoder: JSONDecoder = .githubDecoder) {
        self.session = session
        self.decoder = decoder
    }
    
    // MARK: RepositoryServiceProtocol
    func fetchRepositories(page: Int, perPage: Int) async throws -> [Repository] {
        guard let url = SquareGitHubAPI.squareReposURL(page: page, perPage: perPage) else {
            assertionFailure("Failed to construct GitHub repos URL")
            throw NetworkError.underlying("Invalid URL")
        }
        
        // Create a url request
        let request = URLRequest(url: url)
        
        // MARK: Fetch
        let (data, response): (Data, URLResponse)
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw NetworkError.noConnection
        } catch {
            throw NetworkError.underlying(error.localizedDescription)
        }
        
        // MARK: Validate HTTP status
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NetworkError.httpError(statusCode: http.statusCode)
        }
        
        // MARK: Decode
        do {
            return try self.decoder.decode([Repository].self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error.localizedDescription)
        }
    }
}


// MARK: - JSONDecoder + GitHub convenience
extension JSONDecoder {
    static var githubDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
