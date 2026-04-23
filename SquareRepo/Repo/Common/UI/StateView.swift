//
//  StateView.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import UIKit

class StateView: UIView {
    
    // MARK: Subviews
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .tertiaryLabel
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let retryButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Try Again"
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()
    
    // MARK: Callbacks
    var onRetry: (() -> Void)?

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        backgroundColor = .systemBackground
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: Configuration
    func configure(for state: StateViewConfiguration) {
        switch state {
        case .loading:
            activityIndicator.startAnimating()
            imageView.isHidden = true
            titleLabel.isHidden = true
            messageLabel.isHidden = true
            retryButton.isHidden = true

        case .error(let title, let message):
            activityIndicator.stopAnimating()
            imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            imageView.tintColor = .systemRed
            imageView.isHidden = false
            titleLabel.text = title
            titleLabel.isHidden = false
            messageLabel.text = message
            messageLabel.isHidden = false
            retryButton.isHidden = false

        case .empty:
            activityIndicator.stopAnimating()
            imageView.image = UIImage(systemName: "tray")
            imageView.tintColor = .tertiaryLabel
            imageView.isHidden = false
            titleLabel.text = "No Repositories"
            titleLabel.isHidden = false
            messageLabel.text = "This organisation has no public repositories."
            messageLabel.isHidden = false
            retryButton.isHidden = true
            
        case .noResults:
            activityIndicator.stopAnimating()
            imageView.image = UIImage(systemName: "magnifyingglass")
            imageView.tintColor = .tertiaryLabel
            imageView.isHidden = false
            titleLabel.text = "No Results"
            titleLabel.isHidden = false
            messageLabel.text = "Try a different search term or clear your filters."
            messageLabel.isHidden = false
            retryButton.isHidden = true
        }
    }
    
    // MARK: Layout
    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [
            activityIndicator,
            imageView,
            titleLabel,
            messageLabel,
            retryButton
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
        ])

        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}

// MARK: - StateViewConfiguration
enum StateViewConfiguration {
    case loading
    case error(title: String, message: String)
    case empty
    case noResults
}
