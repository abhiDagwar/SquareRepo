//
//  FilterBarView.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 23/04/26.
//

import UIKit

// MARK: - Delegate
protocol FilterBarViewDelegate: AnyObject {
    /// Called whenever the language selection or archived toggle changes.
    func filterBar(_ bar: FilterBarView, didChangeLanguage language: String?, showArchivedOnly: Bool)
}

// MARK: - FilterBarView
final class FilterBarView: UIView {

    // MARK: Public state
    weak var delegate: FilterBarViewDelegate?

    private(set) var selectedLanguage: String? = nil
    private(set) var showArchivedOnly: Bool = false

    // MARK: Private data
    private var languages: [String] = []

    // "All" is always the first chip (index 0).
    private var allItems: [String] { ["All"] + languages }

    // MARK: Layout
    private enum Layout {
        static let chipHeight: CGFloat = 32
        static let barHeight: CGFloat  = 52
        static let horizontalPad: CGFloat = 12
    }

    // MARK: Subviews
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: Layout.horizontalPad, bottom: 0, right: 8)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(ChipCell.self, forCellWithReuseIdentifier: ChipCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private lazy var archivedButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "Archived"
        config.image = UIImage(systemName: "archivebox")
        config.imagePadding = 4
        config.cornerStyle = .capsule
        config.baseForegroundColor = .systemOrange
        config.baseBackgroundColor = .systemOrange
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(archivedTapped), for: .touchUpInside)
        return btn
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
    /// Replace the available language list and reset selection.
    func setLanguages(_ langs: [String]) {
        guard langs != languages else { return }
        languages = langs
        selectedLanguage = nil
        collectionView.reloadData()
        // Select "All" chip
        collectionView.selectItem(
            at: IndexPath(item: 0, section: 0),
            animated: false,
            scrollPosition: []
        )
    }

    // MARK: Layout
    private func setupLayout() {
        backgroundColor = .systemBackground
        addSubview(collectionView)
        addSubview(archivedButton)
        addSubview(separator)

        NSLayoutConstraint.activate([
            archivedButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPad),
            archivedButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            archivedButton.heightAnchor.constraint(equalToConstant: Layout.chipHeight),

            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: archivedButton.leadingAnchor, constant: -8),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Layout.barHeight)
    }

    // MARK: Actions
    @objc private func archivedTapped() {
        showArchivedOnly.toggle()
        updateArchivedButtonAppearance()
        notifyDelegate()
    }

    private func updateArchivedButtonAppearance() {
        var config = archivedButton.configuration
        config?.baseForegroundColor = showArchivedOnly ? .white : .systemOrange
        config?.baseBackgroundColor = showArchivedOnly ? .systemOrange : .systemOrange
        config?.background.backgroundColor = showArchivedOnly
            ? UIColor.systemOrange
            : UIColor.systemOrange.withAlphaComponent(0.12)
        archivedButton.configuration = config
    }

    private func notifyDelegate() {
        delegate?.filterBar(self, didChangeLanguage: selectedLanguage, showArchivedOnly: showArchivedOnly)
    }
}

// MARK: - UICollectionViewDataSource
extension FilterBarView: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        allItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ChipCell.reuseIdentifier, for: indexPath
        ) as? ChipCell else { fatalError("ChipCell not registered") }

        let title = allItems[indexPath.item]
        cell.configure(title: title)
        // "All" starts selected
        if indexPath.item == 0 && selectedLanguage == nil {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension FilterBarView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // "All" chip deselects the language filter
        selectedLanguage = indexPath.item == 0 ? nil : allItems[indexPath.item]
        notifyDelegate()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension FilterBarView: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        // Size chips to their text content + horizontal padding.
        let title = allItems[indexPath.item]
        let width = (title as NSString).size(withAttributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ]).width + 24
        return CGSize(width: width, height: Layout.chipHeight)
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
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        titleLabel.text = title
        updateAppearance()
    }

    private func updateAppearance() {
        if isSelected {
            contentView.backgroundColor = .systemBlue
            titleLabel.textColor = .white
        } else {
            contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            titleLabel.textColor = .systemBlue
        }
    }
}
