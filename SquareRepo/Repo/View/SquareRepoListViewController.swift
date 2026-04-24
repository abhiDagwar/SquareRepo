//
//  SquareRepoListViewController.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import UIKit

@MainActor
final class SquareRepoListViewController: UIViewController {
    // MARK: Dependencies
    private let viewModel: SquareRepoListViewModel
    
    // MARK: Search
    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.searchBar.delegate = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "Search repositories…"
        sc.searchBar.autocapitalizationType = .none
        return sc
    }()

    // MARK: Filter bar (pinned, always visible)
    private lazy var filterBar: FilterBarView = {
        let bar = FilterBarView()
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    // MARK: Subviews
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(SquareRepoCell.self, forCellReuseIdentifier: SquareRepoCell.reuseIdentifier)
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tv.rowHeight = UITableView.automaticDimension
        // A better estimate reduces the number of layout passes on first load.
        // 100 was too small for repos with long descriptions; 110 is closer to
        // the average once avatar + 2–3 lines of description are factored in.
        tv.estimatedRowHeight = 110
        tv.delegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private lazy var stateView: StateView = {
        let sv = StateView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.isHidden = true
        sv.onRetry = { [weak self] in
            Task { await self?.viewModel.loadRepositories() }
        }
        return sv
    }()

    private let refreshControl = UIRefreshControl()

    // Footer spinner shown while paginating.
    private lazy var footerSpinner: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 48)
        return ai
    }()
    
    private nonisolated enum Section: Hashable { case main }
    
    // MARK: Diffable data source
    private typealias DataSource = UITableViewDiffableDataSource<Section, Repository>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Repository>
    
    private lazy var dataSource: DataSource = {
        UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, repo in
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: SquareRepoCell.reuseIdentifier,
                for: indexPath
            ) as? SquareRepoCell else {
                fatalError("Cell misconfiguration — check reuseIdentifier registration")
            }
            cell.configure(with: repo)
            return cell
        }
    }()
    
    // MARK: Init
    init(viewModel: SquareRepoListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    convenience init() {
        self.init(viewModel: SquareRepoListViewModel())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupLayout()
        bindViewModel()
        // Select the "All" chip on first load.
        filterBar.applyFilter(.all, notify: false)
        Task { await viewModel.loadRepositories() }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure the filter bar header is correctly sized after layout.
        sizeFilterBarHeader()
    }
    
    // MARK: Setup
    private func setupNavigationBar() {
        title = "Square Repositories"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.searchController = searchController
        // Keep search bar visible when scrolled — it's always accessible.
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        //navigationController?.delegate = self
    }
    
    private func setupFilterBar() {
        // The filter bar lives in the tableHeaderView — it scrolls with the
        // list and reappears when the user pulls down, just like the search bar.
        let wrapper = UIView()
        wrapper.addSubview(filterBar)
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            filterBar.topAnchor.constraint(equalTo: wrapper.topAnchor),
            filterBar.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            filterBar.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        tableView.tableHeaderView = wrapper
    }

    private func sizeFilterBarHeader() {
        guard let header = tableView.tableHeaderView else { return }
        let targetHeight = filterBar.intrinsicContentSize.height
        guard header.frame.height != targetHeight else { return }
        header.frame.size.height = targetHeight
        tableView.tableHeaderView = header  // reassign forces layout
    }
    
    private func setupLayout() {
        view.backgroundColor = .systemBackground

        view.addSubview(filterBar)
        view.addSubview(tableView)
        view.addSubview(stateView)

        // Pull-to-refresh — attached to table, disabled during search.
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        NSLayoutConstraint.activate([
            // Filter bar pinned just below the navigation bar.
            filterBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Table fills the space below the filter bar.
            tableView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // State view fills the same space as the table (below the filter bar).
            stateView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state: state)
        }
    }
    
    // MARK: State Rendering
    private func render(state: ViewState) {
        switch state {
        case .idle:
            break

        case .loading:
            showStateView(.loading)

        case .loaded(let repos):
            refreshControl.endRefreshing()
            footerSpinner.stopAnimating()
            // Update language chips. applyFilter keeps the current selection.
            filterBar.setLanguages(viewModel.availableLanguages)
            // Sync the chip UI with the ViewModel's actual active filter.
            filterBar.applyFilter(viewModel.filterState.activeFilter, notify: false)

            if repos.isEmpty {
                showStateView(viewModel.filterState.isActive ? .noResults : .empty)
            } else {
                showTable(repos: repos)
            }

        case .loadingMore(let repos):
            showTable(repos: repos)
            footerSpinner.startAnimating()

        case .failed(let error):
            refreshControl.endRefreshing()
            footerSpinner.stopAnimating()
            showStateView(.error(
                title: "Something went wrong",
                message: error.errorDescription ?? "Unknown error"
            ))
        }
    }

    // MARK: Render helpers
    private func showTable(repos: [Repository]) {
        tableView.isHidden = false
        stateView.isHidden = true
        applySnapshot(repos: repos)
    }

    private func showStateView(_ config: StateViewConfiguration) {
        tableView.isHidden = true
        stateView.isHidden = false
        stateView.configure(for: config)
    }

    private func applySnapshot(repos: [Repository]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(repos, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: Refresh
    /// Only available when search is not active.
    /// Enabled/disabled by searchControllerDelegate methods below.
    @objc private func handleRefresh() {
        Task { await viewModel.loadRepositories() }
    }

    private func setRefreshEnabled(_ enabled: Bool) {
        if enabled {
            tableView.refreshControl = refreshControl
        } else {
            // Dismiss any in-progress refresh first so it doesn't hang.
            refreshControl.endRefreshing()
            tableView.refreshControl = nil
        }
    }
}

// MARK: - UITableViewDelegate
extension SquareRepoListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Trigger pagination as the user approaches the bottom
        Task { await viewModel.loadMoreIfNeeded(currentIndex: indexPath.row) }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Find the selected repo from the diffable snapshot
        guard let repo = dataSource.itemIdentifier(for: indexPath) else { return }

        // Open the repo's GitHub page in Safari.
        UIApplication.shared.open(repo.htmlURL)
    }
}

// MARK: - UISearchResultsUpdating
extension SquareRepoListViewController: UISearchResultsUpdating {

    func updateSearchResults(for sc: UISearchController) {
        viewModel.updateSearch(query: sc.searchBar.text ?? "")
    }
}

// MARK: - UISearchBarDelegate
extension SquareRepoListViewController: UISearchBarDelegate {

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Disable pull-to-refresh while the keyboard / search is active.
        setRefreshEnabled(false)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Cancel clears the search query but preserves the active chip filter.
        viewModel.clearSearch()
        // Re-enable pull-to-refresh once search is dismissed.
        setRefreshEnabled(true)
    }
}

// MARK: - FilterBarViewDelegate
extension SquareRepoListViewController: FilterBarViewDelegate {

    func filterBar(_ bar: FilterBarView, didSelect filter: ActiveFilter) {
        // The ViewModel's selectFilter toggles back to .all if the same
        // filter is tapped again, then publishFiltered() re-derives the list.
        viewModel.selectFilter(filter)
        // Sync the chip UI back — in case the ViewModel toggled to .all.
        filterBar.applyFilter(viewModel.filterState.activeFilter, notify: false)
    }
}
