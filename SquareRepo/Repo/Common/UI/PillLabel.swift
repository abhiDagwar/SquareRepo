//
//  PillLabel.swift
//  SquareRepo
//
//  Created by Abhishek Dagwar on 22/04/26.
//

import UIKit

class PillLabel: UILabel {

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        textColor = .systemBlue
        layer.cornerRadius = 6
        layer.masksToBounds = true
    }

    // MARK: Padding
    // Extra horizontal/vertical padding inside the pill shape.
    private let horizontalPadding: CGFloat = 6
    private let verticalPadding: CGFloat = 2

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(
            width: base.width + horizontalPadding * 2,
            height: base.height + verticalPadding * 2
        )
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
        super.drawText(in: rect.inset(by: insets))
    }
}

// MARK: - Int + abbreviated

extension Int {
    /// Returns a compact string: 1200 → "1.2k", 1_500_000 → "1.5M".
    var abbreviated: String {
        switch self {
        case 1_000_000...:
            return String(format: "%.1fM", Double(self) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fk", Double(self) / 1_000)
        default:
            return "\(self)"
        }
    }
}

