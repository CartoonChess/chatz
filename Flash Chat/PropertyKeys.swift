//
//  PropertyKeys.swift
//  chatz
//
//  Created by Xcode on ’19/09/25.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import Foundation

/// Strings useful globally.
struct AppKeys {
    static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "LabsChat"
    static let appExtensionName = Bundle.init(path: Bundle.main.bundlePath + "/PlugIns/LabsSearchAddEngineAction.appex")?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "LabsChat"
    static let appGroup = "group.com.distantlabs.flashchat"
}

/// Contains some useful URLs.
struct DirectoryKeys {
//    static let userImagesUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppKeys.appGroup)?.appendingPathComponent("Documents/Icons", isDirectory: true)
}


///// Individual preference plists
//struct DefaultsKeys {
//    static let badges = "
//}

/// Contains unchanging key names for all in-app settings.
struct SettingsKeys {
    static let badges = "NotificationBadges"
}
