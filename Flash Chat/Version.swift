//
//  Version.swift
//  chatz
//
//  Created by Xcode on ’19/09/23.
//  Copyright © 2019 London App Brewery. All rights reserved.
//

import Foundation
import Firebase

protocol VersionDelegate: AnyObject {
//    var listenerIndex: Int { get }
    /// Perform any required tasks when the app version is successfully matched against the server.
    func appVersionWasChecked(meetsMinimum: Bool)
}

/// Provides the app's current version number, as well as if it can connect to the server. Access early via `.current.compareAgainstMinimum()`, then register for updates in any subsequent views using `listen()`.
class Version {
    // MARK: - Properties
    
    // This is a singleton
    static let current = Version()
    
    /// Delegates can be notified when `meetsMinimum` receives a value.
//    var listeners = [Int: VersionDelegate]()
    var listeners = [VersionDelegate]()
    
    /// The app's version number, or "0.0.0" if anything has gone wrong.
    var number: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// The app's build number, or "0" if anything has gone wrong.
    var build: Int {
        return Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    }
    
    // Debug
//    var number = "0.0.0"
//    var build = 0
    
    /// Indicates whether the app is new enough to connect to the server.
    private var meetsMinimum: Bool? {
        willSet {
            guard let meetsMinimum = newValue else { return }
            // When set to true, enable Firestore access
            if meetsMinimum { restoreFirebaseConnection() }
            // Notify delegates of the change
            notifyDelegates(meetsMinimum: meetsMinimum)
        }
    }
    
    // Listen for minimum version info from realtime db
    private var versionObserver = UInt()
    
    
    // MARK: - Methods
    
    // Private init forces use of .current()
    private init() {}
    
    
    /// Checks with the server whether the app is up-to-date enough to read and write.
    ///
    /// To test the result of this function, access the `meetsMinimum` property of this instance.
    ///
    /// - Warning:
    /// All access to the Firestore database is blocked until we can verify the client isn't too old. This uses the Realtime database, access to which is left open.
    func compareAgainstMinimum() {
        // We don't need to perform this more than once
        guard meetsMinimum == nil else { return }
        
        Firestore.firestore().disableNetwork { error in
            if let error = error {
                print("❌ Could not disable network before app version check: \(error.localizedDescription)")
            } else {
                print("🏴‍☠️ Network disabled until we check app version.")
                
                // As Firestore is now unreachable, we look for app version info in Realtime database
                let db = Database.database()
                let versionRef = db.reference(withPath: "/public/minimumVersion/iOS")
                // By default, RTDB data should not be cached to disk, only memory;
                //- If we find it is cached anyway, we might consider uncommenting this:
//                db.isPersistenceEnabled = false
                
                // Get iOS minimum version and build
                self.versionObserver = versionRef.observe(.value,
                  with: { snapshot in
                    // This completion block should run any time it finds a value,
                    // so in theory, it should work if we start offline and eventually connect
                    
                    // Success
                    guard let minimum = snapshot.value as? [String: Any],
                        let minimumVersion = minimum["version"] as? String,
                        let minimumBuild = minimum["build"] as? Int else {
                        print("❌ Minimum version in database is incorrectly formatted or couldn't be fetched.")
                        return
                    }
                    print("📱 Minimum version is \(minimumVersion)-\(minimumBuild).")
                    
                    let appVersion = self.number
                    let appBuild = self.build
                    
                    if appVersion > minimumVersion
                        || (appVersion == minimumVersion && appBuild >= minimumBuild) {
                        // We're new enough, so enable Firestore
                        print("📲 We're running \(appVersion)-\(appBuild); preparing to go fully online.")
                        self.meetsMinimum = true
//                        Firestore.firestore().enableNetwork { error in
//                            if let error = error {
//                                print("❌ Could not enable network after app version check: \(error.localizedDescription)")
//                            } else {
//                                print("🏳 Firestore network enabled.")
//                            }
//                        }
                    } else {
                        // We're too old, so don't connect
                        print("☎️ We're running \(appVersion)-\(appBuild); staying mostly offline.")
                        self.meetsMinimum = false
                    }
                    // Kill the observer
                    versionRef.removeObserver(withHandle: self.versionObserver)
                })
                { error in
                    // Failure
                    print("❌ Couldn't observe database for minimum version: \(error.localizedDescription)")
                }
                
            }
        }
    }
    
    /// Call this function to be notified when the app version has been compared.
    /// - Parameter listener: Pass a `VersionDelegate` to receive notifications.
    /// - Returns: A `Bool` if the comparison has already been complete, otherwise `nil`.
    ///
    /// - Warning:
    /// Not sure if this matters, but any object calling this function should probably implement the `stopListening()` function as well, when they are about to be destroyed.
    func listen(from listener: VersionDelegate) {
        // If meetsMinimum is nil, get in line
        guard let meetsMinimum = meetsMinimum else {
            // Add ourselves to listeners list
            listeners.append(listener)
            print("👂 Waiting for app version info.")
            return
        }
        
        // If we already know the value, just return that
        listener.appVersionWasChecked(meetsMinimum: meetsMinimum)
        
//        // Use a random number, so we know who to remove later if one opts out
//        let index = Int.random(in: 0...Int.max)
//        listeners[index] = listener
    }
    
    func stopListening(from delegate: VersionDelegate) {
//        listeners.removeValue(forKey: listener.listenerIndex)
//
//        var delegates = [VersionDelegate]()
        print("🤔 Attempting to kill listener.")
        print("🐛 Count before kill attempt: \(listeners.count)")
        listeners.removeAll { $0 === delegate }
        print("🐛 Count after kill attempt: \(listeners.count)")
    }
    
    private func restoreFirebaseConnection() {
        Firestore.firestore().enableNetwork { error in
            if let error = error {
                print("❌ Could not enable network after app version check: \(error.localizedDescription)")
            } else {
                print("🏳 Firestore network enabled.")
            }
        }
    }
    
    private func notifyDelegates(meetsMinimum: Bool) {
        // Notify any listeners
//        for listener in listeners.values {
        for listener in listeners {
            listener.appVersionWasChecked(meetsMinimum: meetsMinimum)
        }
        // Then kill them
        listeners.removeAll()
        print("☠️ Killed any app version listeners.")
    }
    
}
