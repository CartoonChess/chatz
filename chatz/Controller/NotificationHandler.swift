//
//  NotificationHandler.swift
//  chatz
//
//  Created by Xcode on ’19/10/06.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import UserNotifications

@available(iOS 10, *)
protocol NotificationHandlerDelegate: AnyObject {
    // Allow the highest-level delegate to have the final say in the presentation options
//    var foregroundNotificationPriority: Int { get }
    /// The app would like to show a notification in the foreground
    func willPresentNotification(_ notification: UNNotification, options: (UNNotificationPresentationOptions) -> Void)
    /// The user has tapped a notification
    func didReceiveTapOnNotification(for roomID: String)
    // We should call this to deinit ourselves from delegates list
    func stopReceivingNotifications()
}

@available(iOS 10, *)
class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    // By inhereting from NSObject, we conform to the UN delegate protocol
    
    // MARK: - Properties
    
    // Make it a singleton
    static let current = NotificationHandler()
    // Delegates assign themselves as usual, which pushes them to end of array
    //- Delegates MUST remove themselves later
    //- We shouldn't access this property directly
    var delegate: NotificationHandlerDelegate? {
        get {
            return delegates.last ?? nil
        }
        set {
            if let delegate = newValue {
                delegates.append(delegate)
            }
        }
    }
    private var delegates: [NotificationHandlerDelegate] = []
    // Key for Firebase push notifications
    let gcmMessageIDKey = "gcm.message_id"
    
    // MARK: - Methods
    
    // Private init forces use of .current()
    private override init() {
        super.init()
    }
    
    /// Delegates MUST implement this via stopReceivingNotifications() in order to avoid retention
    func stopSendingNotifications(to delegate: NotificationHandlerDelegate) {
        delegates.removeAll { $0 === delegate }
    }
    
    // Do something with push notifications when app is already in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        var options: UNNotificationPresentationOptions = []
        for index in delegates.indices {
            delegates[index].willPresentNotification(notification) { presentationOptions in
                // Decide what to show of alert/badge/sound
                // Most recent delegate will take priority
                options = presentationOptions
            }
            
        }
        completionHandler(options)
    }
    
    // Triggers when the user taps a notification (whether from fore or background)
    // Handles response options such as dismiss, open, etc.?
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//        let userInfo = response.notification.request.content.userInfo
//
//        // Print message ID
//        if let messageID = userInfo[gcmMessageIDKey] {
//            print("didReceive_response Message ID: \(messageID)")
//        }
//        // Print full message
//        print(userInfo)
        
        print("✴️ userNotificationCenter:didReceive")
        
        // Get the room ID
        let content = response.notification.request.content
        let roomID = content.threadIdentifier
        
        // See if the contacts list is listening
        if let contactsViewIndex = delegates.firstIndex(where: { $0 is ContactsTableViewController }) {
            // Tell contacts view to push to relevant room
            delegates[contactsViewIndex].didReceiveTapOnNotification(for: roomID)
        }
        
        // Let notification center know we dealt with the notification
        completionHandler()
    }
}
