//
//  SquareRepoCell.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import UIKit

class SquareRepoCell: UITableViewCell {
    // MARK: Reuse identifier
    static let reuseIdentifier = "SquareRepoCell"
    
    // MARK: Layout constants
    private enum Layout {
        static let avatarSize: CGFloat    = 44
        static let avatarRadius: CGFloat  = 10
        static let horizontalPad: CGFloat = 16
        static let verticalPad: CGFloat   = 14
        static let avatarTextGap: CGFloat = 12
    }

    // MARK: Subviews
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = Layout.avatarRadius
        iv.backgroundColor = .secondarySystemFill
        // SF symbol shown as placeholder while the real image loads.
        iv.image = UIImage(systemName: "square.grid.2x2.fill")
        iv.tintColor = .tertiaryLabel
        // Fixed size — the avatar never stretches with the row height.
        iv.setContentHuggingPriority(.required, for: .vertical)
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .vertical)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let nameLabel: UILabel = {
            let label = UILabel()
            label.font = .systemFont(ofSize: 16, weight: .semibold)
            label.textColor = .label
            label.numberOfLines = 0
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.setContentHuggingPriority(.defaultHigh, for: .vertical)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        // 0 = show the full description — no truncation at any fixed line count.
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let languageBadge: PillLabel = {
        let pill = PillLabel()
        pill.font = .systemFont(ofSize: 12, weight: .medium)
        pill.translatesAutoresizingMaskIntoConstraints = false
        return pill
    }()
    
    private let starCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let archivedBadge: PillLabel = {
        let pill = PillLabel()
        pill.text = "Archived"
        pill.font = .systemFont(ofSize: 11, weight: .medium)
        pill.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
        pill.textColor = .systemOrange
        pill.translatesAutoresizingMaskIntoConstraints = false
        return pill
    }()
    
    private let statsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // The vertical stack that drives the cell's height.
    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.distribution = .fill
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: Image loading
    /// Retained so prepareForReuse can cancel a stale in-flight fetch.
    private var imageTask: Task<Void, Never>?
    
    // MARK: Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is intentionally not implemented")
    }
    
    // MARK: Configuration
    func configure(with repo: Repository) {
        nameLabel.text = repo.name

        if let desc = repo.description, !desc.isEmpty {
            descriptionLabel.text = desc
            descriptionLabel.isHidden = false
        } else {
            descriptionLabel.isHidden = true
        }

        if let lang = repo.language {
            languageBadge.text = lang
            languageBadge.isHidden = false
        } else {
            languageBadge.isHidden = true
        }

        starCountLabel.text = "★ \(repo.stargazersCount.abbreviated)"
        archivedBadge.isHidden = !repo.isArchived
        
        loadAvatar(url: repo.avatarURL)
    }
    
    // MARK: Avatar loading
    private func loadAvatar(url: URL) {
        // Show placeholder immediately — ensures a recycled cell never
        // briefly shows the previous row's avatar.
        avatarImageView.image = UIImage(systemName: "square.grid.2x2.fill")
        avatarImageView.tintColor = .tertiaryLabel

        imageTask = Task { [weak self] in
            guard let image = await ImageCache.shared.image(for: url) else { return }

            // A fast scroll can cancel this task before the image arrives.
            guard !Task.isCancelled else { return }

            await MainActor.run {
                UIView.transition(
                    with: self?.avatarImageView ?? UIImageView(),
                    duration: 0.2,
                    options: [.transitionCrossDissolve, .allowUserInteraction]
                ) {
                    self?.avatarImageView.image = image
                    self?.avatarImageView.tintColor = nil
                }
            }
        }
    }
    
    // MARK: Layout
    private func setupLayout() {
        // Spacer absorbs leftover horizontal space, pushing badges left.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statsStack.addArrangedSubview(languageBadge)
        statsStack.addArrangedSubview(starCountLabel)
        statsStack.addArrangedSubview(archivedBadge)
        statsStack.addArrangedSubview(spacer)

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(descriptionLabel)
        textStack.addArrangedSubview(statsStack)

        contentView.addSubview(avatarImageView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            // ── Avatar ──────────────────────────────────────────────────
            // Fixed size.
            avatarImageView.widthAnchor.constraint(equalToConstant: Layout.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Layout.avatarSize),
            // Leading + top inset.
            avatarImageView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: Layout.horizontalPad),
            avatarImageView.topAnchor.constraint(
                equalTo: contentView.topAnchor, constant: Layout.verticalPad),

            // ── Text stack ──────────────────────────────────────────────
            // Sits to the right of the avatar.
            textStack.leadingAnchor.constraint(
                equalTo: avatarImageView.trailingAnchor, constant: Layout.avatarTextGap),
            textStack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -Layout.horizontalPad),
            // Top-aligned with the avatar so name and avatar baseline match.
            textStack.topAnchor.constraint(
                equalTo: contentView.topAnchor, constant: Layout.verticalPad),

            // The text stack's bottom drives the cell height.
            // >= guarantees we never clip tall content.
            textStack.bottomAnchor.constraint(
                greaterThanOrEqualTo: contentView.bottomAnchor,
                constant: -Layout.verticalPad),

            // The avatar must also clear the bottom inset so short-text cells
            // still have breathing room below the avatar.
            avatarImageView.bottomAnchor.constraint(
                lessThanOrEqualTo: contentView.bottomAnchor,
                constant: -Layout.verticalPad)
        ])

        // .defaultHigh equality snugs the bottom when text is short,
        // but yields to the >= above when content is tall — the canonical
        // self-sizing cell bottom constraint pattern.
        let snugBottom = textStack.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor, constant: -Layout.verticalPad)
        snugBottom.priority = .defaultHigh
        snugBottom.isActive = true
    }
    
    // MARK: Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        // Cancel any in-flight image fetch so its result can't land on the
        // wrong cell after it's been recycled for a different repo.
        imageTask?.cancel()
        imageTask = nil

        avatarImageView.image = UIImage(systemName: "square.grid.2x2.fill")
        avatarImageView.tintColor = .tertiaryLabel
        nameLabel.text = nil
        descriptionLabel.text = nil
        descriptionLabel.isHidden = true
        languageBadge.text = nil
        languageBadge.isHidden = true
        starCountLabel.text = nil
        archivedBadge.isHidden = true
    }
}
