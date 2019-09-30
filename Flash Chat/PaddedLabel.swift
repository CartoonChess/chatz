//
//  PaddedLabel.swift
//  chatz
//
//  Created by Xcode on ’19/09/29.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

/* Lovingly stolen from SOf.
 https://stackoverflow.com/questions/21167226/resizing-a-uilabel-to-accommodate-insets/55577228#55577228
 */

import UIKit

extension UIEdgeInsets {
   func apply(_ rect: CGRect) -> CGRect {
      return rect.inset(by: self)
   }
}

class PaddedLabel: UILabel {
    var textInsets = UIEdgeInsets.zero {
      didSet { invalidateIntrinsicContentSize() }
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insetRect = bounds.inset(by: textInsets)
        let textRect = super.textRect(forBounds: insetRect, limitedToNumberOfLines: numberOfLines)
        let invertedInsets = UIEdgeInsets(top: -textInsets.top,
                                          left: -textInsets.left,
                                          bottom: -textInsets.bottom,
                                          right: -textInsets.right)
        return textRect.inset(by: invertedInsets)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
}

// Add to Interface Builder
@IBDesignable
extension PaddedLabel {
    @IBInspectable
    var leftTextInset: CGFloat {
        set { textInsets.left = newValue }
        get { return textInsets.left }
    }

    @IBInspectable
    var rightTextInset: CGFloat {
        set { textInsets.right = newValue }
        get { return textInsets.right }
    }

    @IBInspectable
    var topTextInset: CGFloat {
        set { textInsets.top = newValue }
        get { return textInsets.top }
    }

    @IBInspectable
    var bottomTextInset: CGFloat {
        set { textInsets.bottom = newValue }
        get { return textInsets.bottom }
    }
}
