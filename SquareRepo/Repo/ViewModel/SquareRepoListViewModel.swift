//
//  SquareRepoListViewModel.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import Foundation

// MARK: - ViewState
enum ViewState: Equatable {
    case idle
    case loading
    case loaded([Repository])
    case loadingMore([Repository])   // shows existing rows + spinner footer
    case failed(NetworkError)
}

// MARK: ViewModel
@MainActor
final class SquareRepoListViewModel {
    // MARK: Constants
    private let perPage: Int
    private var currentPage: Int = 1
    private var hasMorePages: Bool = true
    
    // MARK: Dependencies
    private let service: RepositoryServiceProtocol
    
    // MARK: State
    private(set) var state: ViewState = .idle {
        didSet { onStateChange?(state) }
    }
    
    // Called on every State transition
    var onStateChange: ((ViewState) -> Void)?
    
    // MARK: Init
    init(perPage: Int = 20, service: RepositoryServiceProtocol? = nil) {
        self.perPage = perPage
        self.service = service ?? GitHubRepositoryService()
    }
    
    // MARK: Public API
    func loadRepositories() async {
        guard state != .loading else { return }

        // Reset pagination on a fresh load.
        currentPage = 1
        hasMorePages = true
        state = .loading

        await fetchPage(page: currentPage, appending: false)
    }

    func loadMoreIfNeeded(currentIndex: Int) async {
        guard case .loaded(let repos) = state,
              hasMorePages,
              currentIndex >= repos.count - 5 else { return }

        state = .loadingMore(repos)
        currentPage += 1
        await fetchPage(page: currentPage, appending: true)
    }
    
    // MARK: Private
    private func fetchPage(page: Int, appending: Bool) async {
        do {
            let fetched = try await service.fetchRepositories(page: page, perPage: perPage)
            
            // Check if more pages are available to fetch by counting fetched count is greater than perPage or not
            hasMorePages = fetched.count == perPage
            
            let existing: [Repository]
            if appending, case .loadingMore(let prev) = state {
                existing = prev
            } else {
                existing = []
            }
            
            state = .loaded(existing + fetched)
        } catch let error as NetworkError {
            // If there is any network error and pagination failed due to that
            // then revert the last list instaed of showing blank page
            if appending, case .loadingMore(let prev) = state {
                state = .loaded(prev)
            } else {
                state = .failed(error)
            }
        } catch {
            state = .failed(.underlying(error.localizedDescription))
        }
    }
}
