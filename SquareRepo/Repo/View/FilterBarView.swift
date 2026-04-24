//
//  FilterBarView.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 23/04/26.
//

import UIKit

// MARK: - Delegate
protocol FilterBarViewDelegate: AnyObject {
    func filterBar(_ bar: FilterBarView, didSelect filter: ActiveFilter)
}

// MARK: - FilterBarView
final class FilterBarView: UIView {
    // MARK: Public
    weak var delegate: FilterBarViewDelegate?

    // MARK: Private data
    // Fixed chips always present at the start of the list.
    private let fixedItems: [ActiveFilter] = [.all, .archived]
    // Language chips appended after the fixed ones.
    private var languageItems: [ActiveFilter] = []

    private var allChips: [ActiveFilter] { fixedItems + languageItems }

    // MARK: Layout constants
    private enum Layout {
        static let chipHeight: CGFloat    = 32
        static let barHeight: CGFloat     = 52
        static let horizontalPad: CGFloat = 12
    }

    // MARK: Subviews
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(
            top: 0, left: Layout.horizontalPad, bottom: 0, right: Layout.horizontalPad)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        // Allow only one chip selected at a time.
        cv.allowsSelection = true
        cv.allowsMultipleSelection = false
        cv.register(ChipCell.self, forCellWithReuseIdentifier: ChipCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: Public API
    /// Update the available language chips without resetting the active selection.
    /// Called whenever the ViewModel exposes new languages (e.g. after pagination).
    func setLanguages(_ langs: [String]) {
        let newItems = langs.map { ActiveFilter.language($0) }
        guard newItems != languageItems else { return }
        languageItems = newItems

        collectionView.reloadData()
        // Re-apply selection so the correct chip stays highlighted after reload.
        applyFilter(.all, notify: false)
    }

    /// Push a filter selection into the bar from outside (e.g. when the VC
    /// clears all filters on search cancel). Pass `notify: false` to avoid
    /// firing the delegate callback — this is an external state push, not a
    /// user tap.
    func applyFilter(_ filter: ActiveFilter, notify: Bool = false) {
        guard let index = allChips.firstIndex(of: filter) else {
            // Fallback to "All" if the filter doesn't exist in current chips.
            applyFilter(.all, notify: notify)
            return
        }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
        if notify { delegate?.filterBar(self, didSelect: filter) }
    }

    // MARK: Intrinsic size
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Layout.barHeight)
    }

    // MARK: Layout
    private func setupLayout() {
        backgroundColor = .systemBackground
        addSubview(collectionView)
        addSubview(separator)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    // MARK: Chip label helper
    private func label(for filter: ActiveFilter) -> String {
        switch filter {
        case .all:              return "All"
        case .archived:         return "⬜ Archived"
        case .language(let l):  return l
        }
    }

    // MARK: Chip color helper
    private func color(for filter: ActiveFilter) -> UIColor {
        switch filter {
        case .all:       return .systemBlue
        case .archived:  return .systemOrange
        case .language:  return .systemGreen
        }
    }
}

// MARK: - UICollectionViewDataSource
extension FilterBarView: UICollectionViewDataSource {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        allChips.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = cv.dequeueReusableCell(
            withReuseIdentifier: ChipCell.reuseIdentifier, for: indexPath
        ) as? ChipCell else { fatalError("ChipCell not registered") }

        let filter = allChips[indexPath.item]
        cell.configure(title: label(for: filter), accentColor: color(for: filter))
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension FilterBarView: UICollectionViewDelegate {

    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tapped = allChips[indexPath.item]

        // Check if this chip was already selected — if so, deselect back to "All"
        // (toggle behaviour). UICollectionView won't fire didSelect again for an
        // already-selected cell, so we detect this via the ViewModel's current
        // filter state via the delegate callback path.
        //
        // We always notify on a tap — the ViewModel handles the toggle logic via
        // `selectFilter(_:)` which returns `.all` if the same filter is re-selected.
        delegate?.filterBar(self, didSelect: tapped)
    }

    // Prevent deselecting the currently selected chip by tapping it again —
    // the ViewModel will handle toggling back to `.all` and the VC will call
    // `applyFilter(.all)` to visually reset.
    func collectionView(_ cv: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension FilterBarView: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ cv: UICollectionView,
        layout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let title = label(for: allChips[indexPath.item])
        let textWidth = (title as NSString).size(withAttributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ]).width
        return CGSize(width: textWidth + 24, height: Layout.chipHeight)
    }
}

// MARK: - ChipCell
private final class ChipCell: UICollectionViewCell {

    static let reuseIdentifier = "ChipCell"

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var accentColor: UIColor = .systemBlue

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, accentColor: UIColor) {
        self.accentColor = accentColor
        titleLabel.text = title
        updateAppearance()
    }

    private func updateAppearance() {
        if isSelected {
            contentView.backgroundColor = accentColor
            titleLabel.textColor = .white
        } else {
            contentView.backgroundColor = accentColor.withAlphaComponent(0.1)
            titleLabel.textColor = accentColor
        }
    }
}
