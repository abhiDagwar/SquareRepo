//
//  SquareRepoTests.swift
//  SquareRepoTests
//
//  Created by Abhishek Dagwar on 21/04/26.
//

import XCTest
@testable import SquareRepo

// MARK: - Mock Service

final class MockRepositoryService: RepositoryServiceProtocol {

    // MARK: Configurable behaviour
    var result: Result<[Repository], NetworkError> = .success([])
    var callCount = 0
    var lastRequestedPage: Int?
    var delay: TimeInterval = 0

    // MARK: RepositoryServiceProtocol
    func fetchRepositories(page: Int, perPage: Int) async throws -> [Repository] {
        callCount += 1
        lastRequestedPage = page

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        switch result {
        case .success(let repos): return repos
        case .failure(let error): throw error
        }
    }
}

// MARK: Test Data
extension Repository {
    static func fixture(
        id: Int = 1,
        name: String = "test-repo",
        description: String? = "A test repository",
        language: String? = "Swift",
        stars: Int = 42,
        isArchived: Bool = false
    ) -> Repository {
        Repository(
            id: id,
            name: name,
            fullName: "square/\(name)",
            description: description,
            language: language,
            stargazersCount: stars,
            forksCount: 5,
            openIssuesCount: 1,
            htmlURL: URL(string: "https://github.com/square/\(name)")!,
            isArchived: isArchived,
            isFork: false,
            updatedAt: Date()
        )
    }
}

// MARK: - ViewModel Tests
@MainActor
final class SquareRepoTests: XCTestCase {

    var sut: SquareRepoListViewModel!
    var mockService: MockRepositoryService!
    
    override func setUp() {
        super.setUp()
        mockService = MockRepositoryService()
        sut = SquareRepoListViewModel(
            perPage: 30,
            service: mockService
        )
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: Initial state
    func test_initialState_isIdle() {
        XCTAssertEqual(sut.state, .idle)
    }
    
    // MARK: Successful load
    func test_loadRepositories_transitionsToLoaded() async {
        let repos = [Repository.fixture(id: 1), Repository.fixture(id: 2)]
        mockService.result = .success(repos)

        await sut.loadRepositories()

        XCTAssertEqual(sut.state, .loaded(repos))
    }

    // MARK: Empty state
    func test_loadRepositories_emptyResponse_staysLoaded() async {
        mockService.result = .success([])

        await sut.loadRepositories()

        XCTAssertEqual(sut.state, .loaded([]))
    }

    // MARK: Failure states
    func test_loadRepositories_noConnection_failsWithCorrectError() async {
        mockService.result = .failure(.noConnection)

        await sut.loadRepositories()

        XCTAssertEqual(sut.state, .failed(.noConnection))
    }

    // MARK: Refresh
    func test_refresh_resetsPaginationToPageOne() async {
        // Simulate being on page 2 already
        let firstPage = (1...30).map { Repository.fixture(id: $0) }
        mockService.result = .success(firstPage)
        await sut.loadRepositories()

        // Refresh
        let freshPage = [Repository.fixture(id: 99)]
        mockService.result = .success(freshPage)
        await sut.loadRepositories()

        XCTAssertEqual(mockService.lastRequestedPage, 1)
        XCTAssertEqual(sut.state, .loaded(freshPage))
    }

    // MARK: Pagination
    func test_loadMore_appendsToExistingList() async {
        // First load returns a full page (= 30 items → hasMorePages = true).
        let page1 = (1...30).map { Repository.fixture(id: $0) }
        mockService.result = .success(page1)
        await sut.loadRepositories()

        // Simulate scrolling near the bottom.
        let page2 = (31...35).map { Repository.fixture(id: $0) }
        mockService.result = .success(page2)
        // Trigger at index 27 (within 5 of the 30-item list end).
        await sut.loadMoreIfNeeded(currentIndex: 27)

        if case .loaded(let combined) = sut.state {
            XCTAssertEqual(combined.count, 35)
        } else {
            XCTFail("Expected .loaded, got \(sut.state)")
        }
    }

    // MARK: State callback
    func test_stateChanges_areBroadcast() async {
        var receivedStates: [ViewState] = []
        sut.onStateChange = { receivedStates.append($0) }

        mockService.result = .success([Repository.fixture()])
        await sut.loadRepositories()

        // We expect: .loading, then .loaded
        XCTAssertEqual(receivedStates.first, .loading)
        XCTAssertTrue(receivedStates.last.map {
            if case .loaded = $0 { return true }
            return false
        } ?? false)
    }
}

// MARK: - NetworkError Tests
final class NetworkErrorTests: XCTestCase {

    func test_noConnection_hasDescription() {
        XCTAssertNotNil(NetworkError.noConnection.errorDescription)
    }

    func test_httpError_includesStatusCode() {
        let error = NetworkError.httpError(statusCode: 429)
        XCTAssertTrue(error.errorDescription?.contains("429") == true)
    }

    func test_decodingFailed_includesDetail() {
        let error = NetworkError.decodingFailed("missingKey")
        XCTAssertTrue(error.errorDescription?.contains("missingKey") == true)
    }
}
