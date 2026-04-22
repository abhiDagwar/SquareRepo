//
//  SquareRepoListViewController.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import UIKit


nonisolated enum Section: Hashable { case main }

@MainActor
final class SquareRepoListViewController: UIViewController {
    // MARK: Dependencies
    private let viewModel: SquareRepoListViewModel
    
    // MARK: Subviews
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(SquareRepoCell.self, forCellReuseIdentifier: SquareRepoCell.reuseIdentifier)
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tv.rowHeight = 100
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
    
    // MARK: Diffable data source
    // private enum Section: Hashable, Sendable { case main }

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

        Task { await viewModel.loadRepositories() }
    }
    
    // MARK: Setup
    private func setupNavigationBar() {
        title = "Square Repositories"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }
    
    private func setupLayout() {
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        view.addSubview(stateView)

        // Pull-to-refresh
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        // Pagination footer — hidden until we're in loadingMore state
        tableView.tableFooterView = footerSpinner

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stateView.topAnchor.constraint(equalTo: view.topAnchor),
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
            stateView.isHidden = false
            stateView.configure(for: .loading)
            tableView.isHidden = true

        case .loaded(let repos):
            refreshControl.endRefreshing()
            footerSpinner.stopAnimating()

            if repos.isEmpty {
                stateView.isHidden = false
                stateView.configure(for: .empty)
                tableView.isHidden = true
            } else {
                stateView.isHidden = true
                tableView.isHidden = false
                apply(repos: repos, animated: true)
            }

        case .loadingMore(let repos):
            // Keep showing the existing list while appending.
            apply(repos: repos, animated: false)
            footerSpinner.startAnimating()

        case .failed(let error):
            refreshControl.endRefreshing()
            footerSpinner.stopAnimating()
            stateView.isHidden = false
            stateView.configure(for: .error(
                title: "Something went wrong",
                message: error.errorDescription ?? "Unknown error"
            ))
            tableView.isHidden = true
        }
    }

    private func apply(repos: [Repository], animated: Bool) {
        var snapshot = Snapshot()
        snapshot.appendSections([Section.main])
        snapshot.appendItems(repos, toSection: Section.main)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }
    
    // MARK: Actions
    @objc private func handleRefresh() {
        Task { await viewModel.loadRepositories() }
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

