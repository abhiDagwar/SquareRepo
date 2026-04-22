//
//  NetworkError.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import Foundation

enum NetworkError: LocalizedError, Equatable {
    case noConnection
    case httpError(statusCode: Int)
    case decodingFailed(String)
    case underlying(String)
    
    // MARK: LocalizedError
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .httpError(let code):
            return "Request failed with status \(code). Please try again later."
        case .decodingFailed(let detail):
            return "Failed to parse data: \(detail)"
        case .underlying(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}
