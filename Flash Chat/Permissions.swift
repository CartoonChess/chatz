//
//  Permissions.swift
//  Flash Chat
//
//  Created by Xcode on ’19/09/17.
//  Copyright © 2019 Distant Labs. All rights reserved.
//

import UIKit
import UserNotifications
import Firebase

enum PermissionsType {
    case notification
}

enum PermissionsOption {
    case includeFirebase
}

struct Permissions {
    // MARK: - Methods
    
    // MARK: - Ask
    
    static func ask(for type: PermissionsType, options: [PermissionsOption] = []) {
        switch type {
        case .notification:
            askForNotifications(options) { (result) in
                switch result {
                case .success(let wasGranted):
                    if wasGranted {
                        // Now that we have permission, register for notifications
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    } else {
                        print("🛑 Notification authorization denied, or possibly not yet decided.")
                    }
                case .failure(let error):
                    print("❌ Error getting notification authorization: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Register for push notifications from Apple, and optionally, Firebase.
    private static func askForNotifications(_ options: [PermissionsOption] = [], completion: @escaping (Result<Bool, Error>) -> Void) {
        if #available(iOS 10.0, *) {
//            for option in options {
//                switch option {
//                case .includeFirebase:
////                    // Also display in-app messages (sent directly via Firebase)
////                    guard let application = application as? MessagingDelegate else {
////                        fatalError("App delegate is not a Firebase messaging delegate.")
////                    }
////                    Messaging.messaging().delegate = application
//                }
//            }
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (wasGranted, error) in
//                if let error = error {
//                    print("❌ Error getting notification authorization: \(error.localizedDescription)")
//                    return
//                } else if wasGranted {
//                    print("🔴 Notification authorization granted!")
//                } else {
//                    print("🛑 Notification authorization denied, or possibly not yet decided.")
//                }
//
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(wasGranted))
                }
            }
            
        } else {
            // iOS < 10
            let authTypes: UIUserNotificationType = [.alert, .badge, .sound]
            let settings = UIUserNotificationSettings(types: authTypes, categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
            
            // Check if user gave permission
            if let settings = UIApplication.shared.currentUserNotificationSettings,
                UIApplication.shared.isRegisteredForRemoteNotifications,
                !settings.types.isEmpty {
                completion(.success(true))
            } else {
                completion(.success(false))
            }
            
        }
        
//        // Now that we have permission, register for notifications
//        DispatchQueue.main.async {
//            UIApplication.shared.registerForRemoteNotifications()
//        }
    }
    
    
    // MARK: - Check
    
    static func didAsk(for type: PermissionsType, completion: @escaping (Bool) -> Void) {
//        var didAsk = false
        
        switch type {
        case .notification:
//            didAskForNotifications { didAsk = $0 }
            didAskForNotifications { completion($0) }
        }
        
//        print("ℹ️ didAsk for \(type): \(didAsk)")
//        return didAsk
    }
    
    private static func didAskForNotifications(completion: @escaping (Bool) -> Void) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { (settings) in
            let authorizationStatus = settings.authorizationStatus
            if authorizationStatus == .authorized {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
////    static func getFirebaseMessagingToken() -> Result<String, Error> {
//    static func getFirebaseMessagingToken() -> String {
//        InstanceID.instanceID().instanceID { (result, error) in
////            guard let result = result else {
////                let error = error ?? NSError(domain: "", code: 0, userInfo: nil)
//////                return .failure(error)
////                return "string"
////            }
//////            return .success(result.token)
////            return "string"
//            return "string"
//        }
////        return "string"
//    }
    
    static func getFirebaseMessagingToken(completion: @escaping (Result<String, Error>) -> Void) {
        InstanceID.instanceID().instanceID { (result, error) in
            guard let result = result else {
                let error = error ?? NSError(domain: "", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }
            completion(.success(result.token))
        }
    }
    
}


//enum InstanceIDError: Error {
//    case `default`
//}
//
//extension InstanceIDError: LocalizedError {
//    public var localizedDescription: String {
//        switch self {
//        case .default:
//            return "asdf"
//        }
//    }
//}
