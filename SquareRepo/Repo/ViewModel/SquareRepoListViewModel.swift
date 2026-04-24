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

// MARK: - ActiveFilter
//
// Single-selection model. The user picks exactly ONE at a time.
//   .all          → show every repo (default)
//   .archived     → show only archived repos
//   .language(x)  → show only repos whose language matches x
enum ActiveFilter: Equatable {
    case all
    case archived
    case language(String)
}

// MARK: - FilterState
struct FilterState: Equatable {
    /// Text typed in the search bar. Empty string = no text filter.
    var searchQuery: String  = ""
    /// The active chip. Default = .all.
    var activeFilter: ActiveFilter = .all
    
    /// True when any filter or search is active — used to decide whether
    /// to show "No Results" vs "Empty" state.
    var isActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        || activeFilter != .all
    }
}

// MARK: ViewModel
@MainActor
final class SquareRepoListViewModel {
    // MARK: Constants
    private let perPage: Int
    private var currentPage: Int = 1
    private var hasMorePages: Bool = true
    
    // MARK: Master data
    /// Full unfiltered list. Only appended to by fetch calls.
    private var allRepositories: [Repository] = []

    // MARK: Filter
    /// Mutating any property synchronously re-derives the visible list via
    /// `publishFiltered()`. Never triggers a network call.
    private(set) var filterState: FilterState = FilterState() {
        didSet {
            guard filterState != oldValue else { return }
            publishFiltered()
        }
    }

    /// Unique languages in the master list, ordered by first appearance.
    /// The filter bar uses this to build language chips.
    var availableLanguages: [String] {
        var seen = Set<String>()
        return allRepositories
            .compactMap(\.language)
            .filter { seen.insert($0).inserted }
    }

    // MARK: Dependencies
    private let service: RepositoryServiceProtocol

    // MARK: State
    private(set) var state: ViewState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState) -> Void)?

    // MARK: Init
    init(perPage: Int = 30, service: RepositoryServiceProtocol? = nil) {
        self.perPage = perPage
        self.service = service ?? GitHubRepositoryService()
    }

    // MARK: Public API — Loading
    /// Full reload. Resets pagination and master list.
    /// Preserves `filterState` so chip + search survive a pull-to-refresh.
    func loadRepositories() async {
        guard state != .loading else { return }
        currentPage = 1
        hasMorePages = true
        allRepositories = []
        state = .loading
        await fetchPage(page: currentPage, appending: false)
    }

    /// Appends the next page when the user approaches the bottom.
    /// Suppressed while any filter is active (issue #4 from the spec).
    func loadMoreIfNeeded(currentIndex: Int) async {
        guard case .loaded(let visible) = state,
              hasMorePages,
              !filterState.isActive,
              currentIndex >= visible.count - 5 else { return }

        state = .loadingMore(visible)
        currentPage += 1
        await fetchPage(page: currentPage, appending: true)
    }

    // MARK: Public API — Search
    /// Called by UISearchResultsUpdating on every keystroke.
    func updateSearch(query: String) {
        filterState.searchQuery = query
    }

    /// Called when the search bar cancel button is tapped.
    /// Clears the text query but preserves the active chip filter.
    func clearSearch() {
        filterState.searchQuery = ""
    }

    // MARK: Public API — Filter chip
    /// Select a filter chip.
    /// If the user taps the chip that's already active, it toggles back to
    /// `.all` — this is how they "deselect" a filter.
    func selectFilter(_ filter: ActiveFilter) {
        filterState.activeFilter = (filterState.activeFilter == filter) ? .all : filter
    }

    /// Resets everything — useful for a "Clear All" button if added later.
    func clearAllFilters() {
        filterState = FilterState()
    }

    // MARK: Private — Fetching
    private func fetchPage(page: Int, appending: Bool) async {
        do {
            let fetched = try await service.fetchRepositories(page: page, perPage: perPage)
            hasMorePages = fetched.count == perPage
            allRepositories += fetched
            publishFiltered()
        } catch let error as NetworkError {
            if appending, case .loadingMore(let prev) = state {
                // Pagination failure: preserve existing visible list.
                state = .loaded(prev)
            } else {
                state = .failed(error)
            }
        } catch {
            state = .failed(.underlying(error.localizedDescription))
        }
    }

    // MARK: Private — Filtering
    /// Derives the visible list from `allRepositories` + `filterState`.
    /// Always emits `.loaded` — never `.failed` or `.loading`.
    private func publishFiltered() {
        let query = filterState.searchQuery.trimmingCharacters(in: .whitespaces)

        let result = allRepositories.filter { repo in
            // 1. Active chip filter (mutually exclusive)
            switch filterState.activeFilter {
            case .all:
                break   // no chip restriction
            case .archived:
                if !repo.isArchived { return false }
            case .language(let lang):
                if repo.language != lang { return false }
            }

            // 2. Text search (name or description, case-insensitive)
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
