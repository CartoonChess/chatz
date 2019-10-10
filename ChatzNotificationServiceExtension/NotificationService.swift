//
//  NotificationService.swift
//  ChatzNotificationServiceExtension
//
//  Created by Xcode on ’19/09/25.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
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
            // Let grouped notif summary know who this is from
            if #available(iOSApplicationExtension 12.0, *) {
                bestAttemptContent.summaryArgument = bestAttemptContent.title
                bestAttemptContent.summaryArgumentCount = 1
            }
            bestAttemptContent.categoryIdentifier = "message"
            
            // Room ID; this also groups them together in notification center
            let threadID = bestAttemptContent.threadIdentifier
            
            // See if this message included a badge number, otherwise assume zero
            let additionalBadges = bestAttemptContent.badge as? Int ?? 0
            
            // Update UserDefaults and app badge
            Badges.increase(for: threadID, with: additionalBadges) { updatedBadge in
                bestAttemptContent.badge = NSNumber(value: updatedBadge)
            }
            
            // Update the notification payload and deliver to user
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler,
            let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
