//
//  AppDelegate.swift
//  Flash Chat
//
//  The App Delegate listens for events from the system. 
//  It recieves application level messages like did the app finish launching or did it terminate etc. 
//

import UIKit
import UserNotifications
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Properties
    var window: UIWindow?
    // Key for Firebash push notifications
    let gcmMessageIDKey = "gcm.message_id"
    
    
    // MARK: - Methods
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        #if DEBUG
            print("🐛 App running in debug mode! 🐛")
        #endif
        
        // Initialise and Configure Firebase
        FirebaseApp.configure()
        // This hides some of the load time behind the launch screen... maybe
        Firestore.firestore()
        
        // Check that app version is new enough to connect to Firebase backend
        // The Firebase connection will be severed, then automatically returned when check is successful
        // Other objects can check .meetsMinimum for true/false (on completion) or nil.
        Version.current.compareAgainstMinimum()
        
        // Set ourselves as the Notification Center delegate (must be performed at app launch)
        // This allows us to display push notifications (sent via APNs)
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        // Also display in-app messages (sent directly via Firebase)
        Messaging.messaging().delegate = self
        
        return true
    }
    
    
    // MARK: - Push notifications
    
    // Because we disabled swizzling, we must provide Firebase the APNs token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("🐛 Firebase Messaging provided with APNs token without swizzling.")
        
        // Add token to user
        guard let user = Auth.auth().currentUser else {
            print("❌ Not logged in, even though we have a messaging token.")
            return
        }
//        Users.updateMessagingToken(for: user)
        user.updateNotificationTokens()
    }
    
    // Or, if we fail
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    // User entered the app by tapping a push notification; this executes once the app loads (see also below)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // Let Firebase know about the message for analytics (since swizzling is disabled)
         Messaging.messaging().appDidReceiveMessage(userInfo)
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("🐛 didReceiveRemoteNotification (no handler); Message ID: \(messageID)")
        }
        print(userInfo)
        
        // TODO: Handle notification data
    }
    
    // User entered the app by tapping a push notification; this executes once the app loads
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Let Firebase know about the message for analytics (since swizzling is disabled)
         Messaging.messaging().appDidReceiveMessage(userInfo)
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("🐛 didReceiveRemoteNotification (with handler); Message ID: \(messageID)")
        }
        print(userInfo)
        
        // TODO: Handle notification data and use completion handler
        completionHandler(UIBackgroundFetchResult.newData)
    }

    
    
    // MARK: - State changes
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        // Clear notifications and badge
        application.applicationIconBadgeNumber = 0
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}


// MARK: - Extensions

@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Do something with push notifications when app is already in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🐛 userNotificationCenter(...willPresent...)")
        let userInfo = notification.request.content.userInfo
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID
        if let messageID = userInfo[gcmMessageIDKey] {
            print("willPresent Message ID: \(messageID)")
        }
        // Print full message
        print(userInfo)
        
        // TODO: Present foreground notifications
        completionHandler([])
    }
    
    // Handles response options to push notifications, such as dismiss, open, etc.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🐛 userNotificationCenter(...didReceive...)")
        let userInfo = response.notification.request.content.userInfo
        // Print message ID
        if let messageID = userInfo[gcmMessageIDKey] {
            print("didReceive_response Message ID: \(messageID)")
        }
        // Print full message
        print(userInfo)
        
        // TODO: Handle notification responses
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    // message(_:didReceiveRegistrationToken:) is called whenever Firebase receives a new token
    // This must be implemented, otherwise AppDelegate doesn't know to receive the Firebase notifications token
    // The userInfo will be referenced by other notification center methods
    // Note: This callback is fired at each app startup and whenever a new token is generated.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("ℹ️ Firebase registration token: \(fcmToken)")
        let userInfo = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: userInfo)
        // This we need maybe to make sure we are using the new token even when the app hasn't relaunched...
        InstanceID.instanceID().instanceID { (result, error) in
            guard let result = result else {
                print("❌ Error fetching Firebase instance ID token: \(error?.localizedDescription ?? "(unknown)")")
                return
            }
            print("✅ Firebase instance ID token: \(result.token)")
        }
        
//        // Make sure token in in users collection, so we know to whom to send messages
//        guard let user = Auth.auth().currentUser else {
//            print("❌ Not logged in, even though we have a messaging token.")
//            return
//        }
//
//        // Add token to user
//        Users.updateMessagingToken(fcmToken, for: user)
    }

    // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground
    // To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true
    // This should only be enabled in two cases:
    // 1. sending upstream messages
    // 2. receiving non-APNs data directly from Firebase
//    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
//        print("Received data message: \(remoteMessage.appData)")
//    }
}



// MARK: - Realtime Database tests

//func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//
//    #if DEBUG
//    print("🐛 App running in debug mode! 🐛")
//    #endif
//
//    // Initialise and Configure Firebase
//    FirebaseApp.configure()
//
//    // Database test
//    let database = Database.database().reference()
//    database.setValue("Best test!")
//    database.child("test").setValue("testinginging")
//    let database = Database.database().reference(withPath: "/test")
//    database.setValue("value!")
//
//    return true
//}
