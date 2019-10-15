//
//  Badges+appIcon.swift
//  chatz
//
//  Created by Xcode on ’19/10/10.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import UIKit

// App ext can't access UIApplication
extension Badges {
    static var appIcon: Int {
        get {
            UIApplication.shared.applicationIconBadgeNumber
        }
        set {
            UIApplication.shared.applicationIconBadgeNumber = newValue
        }
    }
}
