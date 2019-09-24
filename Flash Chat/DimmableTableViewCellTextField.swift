//
//  Dimmable.swift
//  LabsSearch
//
//  Created by Xcode on ’19/03/05.
//  Copyright © 2019 Distant Labs. All rights reserved.
//

import UIKit

/// Visually dims a text field when disabled.
class DimmableTextField: UITextField {
    
    override var isEnabled: Bool {
        willSet {
            switch newValue {
            case true:
                textColor = .darkText
                backgroundColor = .clear
            case false:
                textColor = .systemGray
                if #available(iOS 13, *) {
                    backgroundColor = UIColor.systemGray5
                } else {
                    backgroundColor = UIColor(white: 0.0, alpha: 0.1)
                }
            }
        }
    }

}
