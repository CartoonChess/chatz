//
//  Badges.swift
//  chatz
//
//  Created by Xcode on ’19/10/05.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import UIKit

struct Badges {
    
    // MARK: - Properties
    
    /// All roomIDs and their current badge counts from UserDefaults
    private static var badgesForRooms: [String: Int] {
        UserDefaults(suiteName: AppKeys.appGroup)?.dictionary(forKey: SettingsKeys.badges) as? [String: Int] ?? [:]
    }
    
    /// Sum of all badges in UserDefaults plist
    static var totalUnread: Int {
        //        let allBadgesCounts = Array(allBadges.values)
        //        return allBadgesCounts.reduce(0, +) // "start at 0, + each value"
        badgesForRooms.values.reduce(0, +) // "start at 0, + each value"
    }
    
    
    // MARK: - Methods
    
    /// Clear all room badges
    static func removeAll() {
        UserDefaults(suiteName: AppKeys.appGroup)?.removeObject(forKey: SettingsKeys.badges)
    }
    
    /// Clear a room's badge count
    static func remove(for roomID: String, completion: ((Int) -> Void)? = nil) {
        replace(for: roomID, withBadge: 0) { completion?($0) }
    }
    
    /// Replace a room's badge count, disregarding the previous count
    static func replace(for roomID: String, withBadge count: Int, completion: ((Int) -> Void)? = nil) {
        update(for: roomID, withBadge: count, ignoreExistingBadges: true) { completion?($0) }
    }
    
    /// Add onto a room's badge count with a given value. Returns the new total count
    ///
    /// Note that threadID also groups notifications together in notification center
    static func increase(for roomID: String, with additionalBadges: Int, completion: ((Int) -> Void)? = nil) {
        update(for: roomID, withBadge: additionalBadges) { completion?($0) }
    }
    
    private static func update(for roomID: String, withBadge count: Int, ignoreExistingBadges: Bool = false, completion: ((_ totalUnread: Int) -> Void)? = nil) {
//        // Get all current badge counts from UserDefaults
//        var allBadges = UserDefaults(suiteName: AppKeys.appGroup)?.dictionary(forKey: SettingsKeys.badges) as? [String: Int] ?? [:]
        // Create mutable copy
        var badgesForThreads = badgesForRooms
        
        var newBadgesCountForThread = count
        
        // If we're not explicitly specifying the final badge count, add it to the previous value
        if !ignoreExistingBadges {
            // Current for this thread
            let currentBadgesForThread = badgesForThreads[roomID] ?? 0
            // Update badge for room
            newBadgesCountForThread = currentBadgesForThread + newBadgesCountForThread
        }
        
        if newBadgesCountForThread > 0 {
            badgesForThreads[roomID] = newBadgesCountForThread
        } else {
            // Remove room when set to zero
            badgesForThreads.removeValue(forKey: roomID)
        }
        // Write back to defaults
        UserDefaults(suiteName: AppKeys.appGroup)?.set(badgesForThreads, forKey: SettingsKeys.badges)
        
//        // Update app badge to reflect total unread count
//        let allBadgesCounts = Array(badgesForThreads.values)
//        let appTotalBadges = allBadgesCounts.reduce(0, +) // "start at 0, + each value"
        // Allow receiver to update app badge
        completion?(totalUnread)
//        completion?(appTotalBadges)
    }
    
}
