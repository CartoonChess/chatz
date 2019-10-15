//
//  UISwitch+darkModeThumb.swift
//  chatz
//
//  Created by Xcode on ’19/10/05.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import UIKit

/// Change the thumb colour on a switch to reflect light/dark mode
class AppearanceSwitch: UISwitch {
    private func finishInit() {
        thumbTintColor = .systemAppearanceBackground
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        finishInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        finishInit()
    }
}
