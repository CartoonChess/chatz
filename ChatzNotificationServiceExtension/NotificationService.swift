//
//  NotificationService.swift
//  ChatzNotificationServiceExtension
//
//  Created by Xcode on ’19/09/25.
//  Copyright © 2019 London App Brewery. All rights reserved.
//

// Allows us to modify the data (not appearance) of notifications

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
//            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
//            bestAttemptContent.body = "\(bestAttemptContent.body) [modified]"
            
            // See if this message included a badge number, otherwise assume zero
            let additionalBadges = bestAttemptContent.badge as? Int ?? 0
            
            // Get current badge count from UserDefaults
            let currentBadges = UserDefaults(suiteName: AppKeys.appGroup)?.integer(forKey: SettingsKeys.badges) ?? 0

            // Increase current count by payload's badge number and write back to UserDefaults
            let totalBadges = currentBadges + additionalBadges
            UserDefaults(suiteName: AppKeys.appGroup)?.set(totalBadges, forKey: SettingsKeys.badges)
            
            // Update badge to reflect total unread count
            bestAttemptContent.badge = NSNumber(value: totalBadges)
            
            // Update the notification payload and deliver to user
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
