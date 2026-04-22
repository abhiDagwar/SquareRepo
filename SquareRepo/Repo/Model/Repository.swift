//
//  Repository.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 21/04/26.
//

import Foundation

nonisolated
struct Repository: Codable, Equatable, Hashable {
    // MARK: Stored Properties
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let htmlURL: URL
    let avatarURL: URL         // flattened from owner.avatar_url
    let isArchived: Bool
    let isFork: Bool
    let updatedAt: Date
    
    // MARK: Nested types
    /// Intermediate decode-only type for the `owner` JSON object.
    /// Not exposed publicly — we flatten what we need onto Repository.
    private struct Owner: Codable {
        let avatarURL: URL
        enum CodingKeys: String, CodingKey {
            case avatarURL = "avatar_url"
        }
    }
    
    // MARK: CodingKeys
    // The API uses snake_case which we need in camelCasing and property such as `fork` rewrite to match with type Bool
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName        = "full_name"
        case description
        case language
        case stargazersCount = "stargazers_count"
        case forksCount      = "forks_count"
        case openIssuesCount = "open_issues_count"
        case htmlURL         = "html_url"
        case owner
        case isArchived      = "archived"
        case isFork          = "fork"
        case updatedAt       = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(Int.self,    forKey: .id)
        name           = try c.decode(String.self, forKey: .name)
        fullName       = try c.decode(String.self, forKey: .fullName)
        description    = try c.decodeIfPresent(String.self, forKey: .description)
        language       = try c.decodeIfPresent(String.self, forKey: .language)
        stargazersCount = try c.decode(Int.self,   forKey: .stargazersCount)
        forksCount     = try c.decode(Int.self,    forKey: .forksCount)
        openIssuesCount = try c.decode(Int.self,   forKey: .openIssuesCount)
        htmlURL        = try c.decode(URL.self,    forKey: .htmlURL)
        isArchived     = try c.decode(Bool.self,   forKey: .isArchived)
        isFork         = try c.decode(Bool.self,   forKey: .isFork)
        updatedAt      = try c.decode(Date.self,   forKey: .updatedAt)
        // Flatten owner.avatar_url → avatarURL
        let owner      = try c.decode(Owner.self,  forKey: .owner)
        avatarURL      = owner.avatarURL
    }

    // Explicit encode keeps Codable round-trips working (e.g. in snapshot tests).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,             forKey: .id)
        try c.encode(name,           forKey: .name)
        try c.encode(fullName,       forKey: .fullName)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(language,    forKey: .language)
        try c.encode(stargazersCount, forKey: .stargazersCount)
        try c.encode(forksCount,      forKey: .forksCount)
        try c.encode(openIssuesCount, forKey: .openIssuesCount)
        try c.encode(htmlURL,         forKey: .htmlURL)
        try c.encode(isArchived,      forKey: .isArchived)
        try c.encode(isFork,          forKey: .isFork)
        try c.encode(updatedAt,       forKey: .updatedAt)
        // Re-wrap into owner shape for encoding
        try c.encode(Owner(avatarURL: avatarURL), forKey: .owner)
    }

    // MARK: Memberwise init (used by test fixtures)

    init(
        id: Int,
        name: String,
        fullName: String,
        description: String?,
        language: String?,
        stargazersCount: Int,
        forksCount: Int,
        openIssuesCount: Int,
        htmlURL: URL,
        avatarURL: URL,
        isArchived: Bool,
        isFork: Bool,
        updatedAt: Date
    ) {
        self.id              = id
        self.name            = name
        self.fullName        = fullName
        self.description     = description
        self.language        = language
        self.stargazersCount = stargazersCount
        self.forksCount      = forksCount
        self.openIssuesCount = openIssuesCount
        self.htmlURL         = htmlURL
        self.avatarURL       = avatarURL
        self.isArchived      = isArchived
        self.isFork          = isFork
        self.updatedAt       = updatedAt
    }
}

extension Repository {
    nonisolated static func == (lhs: Repository, rhs: Repository) -> Bool {
        return lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

