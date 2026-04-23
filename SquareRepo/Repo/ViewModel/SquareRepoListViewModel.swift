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

// MARK: - FilterState

/// All active filter criteria in one place.
/// A struct rather than loose properties so we can pass it around and
/// compare snapshots easily in tests.
struct FilterState: Equatable {
    var searchQuery: String  = ""
    var language: String?    = nil   // nil = no language filter
    var showArchivedOnly: Bool = false
}

// MARK: ViewModel
@MainActor
final class SquareRepoListViewModel {
    // MARK: Constants
    private let perPage: Int
    private var currentPage: Int = 1
    private var hasMorePages: Bool = true
    
    // MARK: Data
    /// Master list — everything fetched so far, unfiltered.
    private var allRepositories: [Repository] = []

    // MARK: Filter
    var filterState: FilterState = FilterState() {
        didSet {
            guard filterState != oldValue else { return }
            // Re-derive the filtered list and publish it.
            publishFiltered()
        }
    }

    /// All unique languages found in the current master list.
    /// Used by the filter bar to populate language chip options.
    var availableLanguages: [String] {
        let langs = allRepositories.compactMap(\.language)
        // Preserve insertion order (order by first appearance).
        var seen = Set<String>()
        return langs.filter { seen.insert($0).inserted }
    }
    
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
    
    // MARK: Public API — Search & Filter
    func updateSearch(query: String) {
        filterState.searchQuery = query
    }

    func updateLanguageFilter(_ language: String?) {
        filterState.language = language
    }

    func toggleArchivedFilter() {
        filterState.showArchivedOnly.toggle()
    }

    func clearAllFilters() {
        filterState = FilterState()
    }
    
    // MARK: Private — Fetching
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
    
    // MARK: Private — Filtering
    /// Derives the visible list from `allRepositories` + `filterState`
    /// and pushes it to the VC via `state`.
    private func publishFiltered() {
        let result = allRepositories.filter { repo in
            // 1. Archived filter
            if filterState.showArchivedOnly, !repo.isArchived { return false }

            // 2. Language filter
            if let lang = filterState.language, repo.language != lang { return false }

            // 3. Search query — match name or description, case-insensitive
            let query = filterState.searchQuery.trimmingCharacters(in: .whitespaces)
            if !query.isEmpty {
                let nameMatch = repo.name.localizedCaseInsensitiveContains(query)
                let descMatch = repo.description?.localizedCaseInsensitiveContains(query) ?? false
                if !nameMatch && !descMatch { return false }
            }

            return true
        }

        state = .loaded(result)
    }
}
