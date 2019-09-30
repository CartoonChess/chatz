//
//  UserProfile.swift
//  Flash Chat
//
//  Created by Xcode on ’19/09/16.
//  Copyright © 2019 Distant Labs. All rights reserved.
//

import Foundation
import Firebase

protocol UsersListener {
    func usersDidUpdate()
}

/// All users we've seen, so we can cache this data
class Users {
    var profiles: [UserProfile]
    var views: [UserProfileView]
    private var listener: ListenerRegistration?
    
    // TODO: Later, we would set listeners on friends list and then chatrooms as we visit them
    // This way, we see name changes, but don't have to poll people unimportant to us
    // We have to keep a list of friends and a list of users for each chat, otherwise we poll the entire database
    
    init() {
        self.profiles = []
        self.views = []
//        self.listener = ListenerRegistration
    }
    
//    func get(completion: (() -> Void)? = nil) {
//        listener = addListener()
//    }
    
    func removeListener() {
        listener?.remove()
    }
    
    deinit {
        print("☠️ Killing Users object and taking its listener with it.")
        listener?.remove()
    }
    
    private func addUser(_ profile: UserProfile) {
        profiles.append(profile)
        let view = UserProfileView(user: profile)
        views.append(view)
    }
    
    private func updateUser(_ profile: UserProfile, at profilesIndex: Int, and viewsIndex: Int? = nil) {
        profiles[profilesIndex] = profile
        let viewsIndex = viewsIndex != nil ? viewsIndex! : profilesIndex
        views.remove(at: viewsIndex)
    }
    
    private func removeUser(at profilesIndex: Int, and viewsIndex: Int? = nil) {
        profiles.remove(at: profilesIndex)
        let viewsIndex = viewsIndex != nil ? viewsIndex! : profilesIndex
        views.remove(at: viewsIndex)
    }
    
//    private var listener: ListenerRegistration {
//        let users = Firestore.firestore().collection("users")
//        return users.addSnapshotListener { (snapshot, error) in
//            guard let snapshot = snapshot else {
//                print("❌ Failed to fetch user profiles: \(error?.localizedDescription ?? "(unknown error)")")
//                return
//            }
//
//            for change in snapshot.documentChanges {
//                let id = change.document.documentID
//                let profile = change.document.data()
//                let user = UserProfile(id: id, profile)
//
//                switch change.type {
//                case .added:
//                    guard let user = user else {
//                        print("❌ Found user but couldn't create profile from server data.")
//                        continue
//                    }
//                    print("✅ Got user \(user.name).")
//                    self.profiles.append(user)
//                case .modified:
//                    guard let user = user else {
//                        print("❌ User modified but couldn't create profile from server data.")
//                        continue
//                    }
//                    guard let index = self.profiles.firstIndex(where: { $0.id == id }) else {
//                        print("❌ User modified but couldn't find profile in local data.")
//                        continue
//                    }
//                    print("⚠️ User \(user.name) modified.")
//                    self.profiles[index] = user
//                case .removed:
//                    guard let index = self.profiles.firstIndex(where: { $0.id == id }) else {
//                        print("❌ User deleted but couldn't find profile in local data.")
//                        continue
//                    }
//                    print("❌ User deleted.")
//                    self.profiles.remove(at: index)
//                @unknown default:
//                    fatalError("User profile changed in an unexpected way!")
//                }
//            }
//        }
//    }
    
    func fetch(completion: (() -> Void)? = nil) {
        let users = Firestore.firestore().collection("users")
        let listener = users.addSnapshotListener { (snapshot, error) in
            guard let snapshot = snapshot else {
                print("❌ Failed to fetch user profiles: \(error?.localizedDescription ?? "(unknown error)")")
                return
            }

            for change in snapshot.documentChanges {
                let id = change.document.documentID
                let profile = change.document.data()
                let user = UserProfile(id: id, profile)

                switch change.type {
                case .added:
                    guard let user = user else {
                        print("❌ Found user but couldn't create profile from server data.")
                        continue
                    }
                    print("✅ Got user \(user.name).")
//                    self.profiles.append(user)
                    self.addUser(user)
                case .modified:
                    guard let user = user else {
                        print("❌ User modified but couldn't create profile from server data.")
                        continue
                    }
                    guard let profilesIndex = self.profiles.firstIndex(where: { $0.id == id }),
                        let viewsIndex = self.views.firstIndex(where: { $0.user.id == id }) else {
                        print("❌ User modified but couldn't find profile in local data.")
                        continue
                    }
                    print("⚠️ User \(user.name) modified.")
//                    self.profiles[index] = user
                    if viewsIndex == profilesIndex {
                        self.updateUser(user, at: profilesIndex)
                    } else {
                        self.updateUser(user, at: profilesIndex, and: viewsIndex)
                    }
                case .removed:
                    guard let profilesIndex = self.profiles.firstIndex(where: { $0.id == id }),
                        let viewsIndex = self.views.firstIndex(where: { $0.user.id == id }) else {
                        print("❌ User deleted but couldn't find profile in local data.")
                        continue
                    }
                    print("❌ User deleted.")
//                    self.profiles.remove(at: index)
                    if viewsIndex == profilesIndex {
                        self.removeUser(at: profilesIndex)
                    } else {
                        self.removeUser(at: profilesIndex, and: viewsIndex)
                    }
                @unknown default:
                    fatalError("🛑 User profile changed in an unexpected way!")
                }
            }
            completion?()
        }
        self.listener = listener
    }
    
    // MARK: - Messaging token
    
//    // Call this when logging in/registering, to add token and make sure no one else is using it
//    static func updateMessagingToken(_ knownToken: String = "", for user: User) {
//        // We can accept the token if it's known, or else look it up
//        var token = ""
//        if !knownToken.isEmpty {
//            token = knownToken
//        } else {
//            // If function was called without a token, fetch it, or give up if we can't
//            Permissions.getFirebaseMessagingToken { (result) in
//                switch result {
//                case .success(let fcmToken):
//                    print("✅ Firebase instance ID token: \(fcmToken)")
//                    token = fcmToken
//                case .failure(let error):
//                    print("❌ Error fetching Firebase instance ID token: \(error)")
//                    return
//                }
//
//                print("💰 Adding token: \(token).")
//
//                // Add/update token subcollection
//                // We can call this at the same time as remove won't remove from self
//                UserProfile.addNotificationToken(token, for: user)
//            }
//        }
//    }
//    static func updateMessagingToken(_ knownToken: String = "", for user: User) {
//        // We can accept the token if it's known, or else look it up
//        var token = ""
//        if !knownToken.isEmpty {
//            token = knownToken
//        } else {
//            // If function was called without a token, fetch it, or give up if we can't
//            Permissions.getFirebaseMessagingToken { (result) in
//                switch result {
//                case .success(let fcmToken):
//                    print("✅ Firebase instance ID token: \(fcmToken)")
//                    token = fcmToken
//                case .failure(let error):
//                    print("❌ Error fetching Firebase instance ID token: \(error)")
//                    return
//                }
//
//                print("🐛🐛🐛 Adding token: \(token).")
//
//                // Add/update token subcollection
//                // We can call this at the same time as remove won't remove from self
//                UserProfile.addNotificationToken(token, for: user)
//                // Remove token from anyone who had been using that device
//                let usersDB = Firestore.firestore().collection("users")
//                usersDB.whereField("tokens", arrayContains: token).getDocuments { (snapshot, error) in
//                    guard let snapshot = snapshot else {
//                        print("❌ Failed to fetch previous users of token: \(error?.localizedDescription ?? "(unknown error)")")
//                        return
//                    }
//                    for document in snapshot.documents {
//                        // Remove token from anyone but self
//                        if document.documentID != user.uid {
//                            let data = document.data()
//                            guard let oldTokens = data["tokens"] as? [String] else {
//                                print("❌ Couldn't read the tokens array.")
//                                continue
//                            }
//                            // Remove token from array
//                            let newTokens = oldTokens.filter { $0 != token }
//                            // Update document
//                            let documentID = document.documentID
//                            usersDB.document(documentID).updateData(["tokens": newTokens]) { (error) in
//                                if let error = error {
//                                    print("❌ Could not remove tokens from \(documentID): \(error)")
//                                } // if error
//                                print("🗑 Removed token from previously logged in user \(data["name"] ?? "(unknown)").")
//                            } // updateData()
//                        } // if != user.uid
//                    } // for document
//                } // getDocuments()
//            } // getFirebaseMessagingToken()
//        } // knownToken.isEmpty
//    } // updateMessagingToken()
    
//    static func removeMessagingToken(for user: String?, completion: @escaping (String?) -> Void) {
//        guard let uid = user else {
//            completion("❌ User string is nil.")
//            return
//        }
//
//        // Get current token
//        var token = ""
//        InstanceID.instanceID().instanceID { (result, error) in
//            guard let result = result else {
//                completion("❌ Error fetching Firebase instance ID token: \(error?.localizedDescription ?? "(unknown)")")
//                return
//            }
//            token = result.token
//            print("✅ Firebase instance ID token: \(token)")
//        }
//
//        // Remove from user doc
//        let usersDB = Firestore.firestore().collection("users")
//
//        // First, get user's existing tokens
//        usersDB.document(uid).getDocument { (snapshot, error) in
//            guard let snapshot = snapshot,
//                let data = snapshot.data(),
//                var tokens = data["tokens"] as? [String] else {
//                completion("❌ Failed to fetch user tokens: \(error?.localizedDescription ?? "(unknown error)")")
//                return
//            }
//            tokens.removeAll { $0 == token }
//
//            // Now, replace the array with the token removed
//            usersDB.document(uid).updateData(["tokens": tokens]) { (error) in
//                if let error = error {
//                    completion("❌ Could not store messaging token in user document: \(error)")
//                    return
//                }
//                print("🗑 Removed notification token from user profile.")
//                completion(nil)
//            }
//        }
//
//    }
    
}

struct UserProfileView {
    let user: UserProfile
    
//    var color = UIColor(white: 0, alpha: 1)
//
//    mutating func updateUserColor(_ color: UIColor?) -> UIColor {
//        var color = color
//        // Create a new color if we haven't assigned one yet
//        if color == nil {
//            let red = CGFloat.random(in: 0.0...1.0)
//            let green = CGFloat.random(in: 0.0...1.0)
//            let blue = CGFloat.random(in: 0.0...1.0)
//            color = UIColor(red: red, green: green, blue: blue, alpha: 1)
//        }
//        // Update ourself
//        self.color = color!
//        // And keep track in table view controller
//        return color!
//    }
    
//    private var color_: UIColor?
//    var color: UIColor {
//        get {
//            if let color = color_ {
//                return color
//            } else {
//                return UIColor.random
//            }
//        }
//        set {
//            color_ = newValue
//        }
//    }
    let color: UIColor
    
    init(user: UserProfile, color: UIColor? = nil) {
        self.user = user
        self.color = color ?? UIColor.random
//        if let color = color {
//            self.color_ = color
//        } else {
//            self.color_ = UIColor.random
//        }
    }
}

/// Custom user object representing user info tied to UID
struct UserProfile: Decodable {
    let id: String
    let email: String
    let name: String
    
//    /// For sending to Firebase to create document
//    private var document: [String: String] {
//        return [
//            "email": email,
//            "name": name
//        ]
//    }
    
    
//    func setProfileName(_ name: String, for user: User, updateUserDocument: Bool = true, completion: @escaping (String?) -> Void) {
//        UserProfile.setProfileName(name, for: user, updateUserDocument: updateUserDocument) { (error) in completion(error) }
//    }
    
//    static func setProfileName(_ name: String, for user: User, updateUserDocument: Bool = true, completion: @escaping (String?) -> Void) {
//        let setNameRequest = user.createProfileChangeRequest()
//        setNameRequest.displayName = name
//        setNameRequest.commitChanges { (error) in
//            if let error = error {
//                completion("❌ Error updating users collection: \(error.localizedDescription)")
//                return
//            }
//
//            if updateUserDocument {
//                self.updateUserDocument(for: user) { (error) in
//                    completion(error)
//                }
//            } else {
//                completion(nil)
//            }
//        }
//    }
    
    
//    func updateUserDocument(completion: @escaping (String?) -> Void) {
//        UserProfile.updateUserDocument(for: UserProfile(self)) { (error) in completion(error) }
//    }
    
//    /// Add user to users collection, so others can access their profile info
//    static func updateUserDocument(for user: User, completion: @escaping (String?) -> Void) {
//        guard let name = user.displayName,
//            let email = user.email else {
//            completion("❌ Couldn't get user name or email to add user document.")
//            return
//        }
//
//        let users = Firestore.firestore().collection("users")
//        let uid = user.uid
//        let user = UserProfile(id: uid, email: email, name: name)
//        // Document ID matches user ID
//        users.document(uid).setData(user.document) { (error) in
//            if let error = error {
//                completion("❌ Error updating users collection: \(error.localizedDescription)")
//                return
//            }
//            print("👋 User profile added to users collection.")
//            completion(nil)
//        }
//    }
    
    
//    func addNotificationToken(_ token: String, for user: User) {
//        UserProfile.addNotificationToken(token, for: user)
//    }
    
//    static func addNotificationToken(_ token: String, for user: User) {
//        let usersDB = Firestore.firestore().collection("users")
//
//        // First, get user's existing tokens, if applicable
//        usersDB.document(user.uid).getDocument { (snapshot, error) in
//            guard let snapshot = snapshot,
//                let data = snapshot.data() else {
//                    let error = error?.localizedDescription ?? "(unknown error)"
//                    print("❌ Failed to fetch user tokens: \(error)")
//                    return
//            }
//
//            // Existing tokens, or else empty array
//            var tokens = data["tokens"] as? [String] ?? []
//
//            tokens.append(token)
//
//            // Replace or add array
//            usersDB.document(user.uid).updateData(["tokens": tokens]) { (error) in
//                if let error = error {
//                    let error = error.localizedDescription
//                    print("❌ Could not store messaging token in user document: \(error)")
//                    return
//                }
//            }
//
//            print("💰 Added token to user document.")
//        }
//    }
    
//    /// Init for creating Firebase document
//    init(id: String, email: String, name: String) {
//        self.id = id
//        self.email = email
//        self.name = name
//    }
    
    /// Init from Firebase document
    init?(id: String, _ values: [String: Any]) {
        guard let email = values["email"] as? String,
            let name = values["name"] as? String else {
                print("❌ Problem fetching user email or name.")
                return nil
        }
        self.id = id
        self.email = email
        self.name = name
    }
    
//    /// Init from Firebase User object
//    init?(_ user: User) {
//        guard let email = user.email,
//            let name = user.displayName else {
//            return nil
//        }
//
//        self.id = user.uid
//        self.email = email
//        self.name = name
//    }
}


extension User {
    // MARK: Properties
    
    /// For sending to Firebase to create document
    var document: [String: String]? {
        guard let name = displayName,
            let email = email else {
            return nil
        }
        return [
            "email": email,
            "name": name
        ]
    }
    
    // MARK: Profile methods
    
    /// Update user object in Firebase auth to include readable name
    func setProfileName(_ name: String, completion: @escaping (String?) -> Void) {
        let setNameRequest = self.createProfileChangeRequest()
        setNameRequest.displayName = name
        setNameRequest.commitChanges { (error) in
            if let error = error {
                completion("❌ Error updating users collection: \(error.localizedDescription)")
                return
            }
            
//            if updateUserDocument {
                self.updateUserDocument() { (error) in
                    completion(error)
                }
//            } else {
                completion(nil)
            }
//        }
    }
    
    /// Add user to users collection, so others can access their profile info
    func updateUserDocument(completion: @escaping (String?) -> Void) {
        guard let document = self.document else {
            completion("❌ Couldn't get user name or email to add user document.")
            return
        }
        
        let users = Firestore.firestore().collection("users")
        let uid = self.uid
//        let user = UserProfile(id: uid, email: email, name: name)
        // Document ID matches user ID
        users.document(uid).setData(document) { (error) in
            if let error = error {
                completion("❌ Error updating users collection: \(error.localizedDescription)")
                return
            }
            print("👋 User profile added to users collection.")
            completion(nil)
        }
    }
    
    /// Add user to the global group chat
    func joinGroupChat() {
        let uid = self.uid
        let participantsDB = Firestore.firestore().collection("rooms").document("groupchat").collection("participants")
        // Check if we're already in there
        participantsDB.whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
            guard let snapshot = snapshot else {
                print("❌ Group chat participants collection unavailable: \(error?.localizedDescription ?? "(unknown error)")")
                return
            }
            if snapshot.count == 0 {
                // We're not here yet, so add ourselves
                print("ℹ️ Adding ourselves to the group chat.")
                participantsDB.addDocument(data: ["uid": uid]) { error in
                    if let error = error {
                        print("❌ Could not create participant document: \(error.localizedDescription)")
                    }
                }
            } else {
                
                print("✅ We're already in the group chat.")
            }
        }
    }
    
    // MARK: Notification token methods
    
    /// Call this when logging in or registering to add push notification token to user doc
    func updateNotificationTokens(token knownToken: String = "") {
        // We can accept the token if it's known, or else look it up
        var token = ""
        if !knownToken.isEmpty {
            token = knownToken
        } else {
            // If function was called without a token, fetch it, or give up if we can't
            Permissions.getFirebaseMessagingToken { (result) in
                switch result {
                case .success(let fcmToken):
                    token = fcmToken
                case .failure(let error):
                    print("❌ Error fetching Firebase instance ID token: \(error)")
                    return
                }
                
                print("💰 Adding token: \(token).")
                
                // Add to/update token subcollection
                // We wrote a cloud function to take care of removing duplicates from other users when this is done
                let usersDB = Firestore.firestore().collection("users")
                let tokensCollection = usersDB.document(self.uid).collection("notificationTokens")
                
                // First, get user's existing tokens, if applicable
                tokensCollection.getDocuments { (snapshot, error) in
                    guard let snapshot = snapshot else {
                        print("❌ Failed to fetch user notification tokens: \(error?.localizedDescription ?? "(unknown error)")")
                        return
                    }
                    
                    // Make sure we're not duplicating this token if it already exists
                    if !snapshot.isEmpty {
                        for tokenDoc in snapshot.documents {
                            let tokenData = tokenDoc.data()
                            if let oldToken = tokenData["token"] as? String,
                                oldToken == token {
                                print("💵 Token already exists on server.")
                                return
                            }
                        }
                    }
                    
                    // If we haven't found a matching token, add the current one
                    tokensCollection.addDocument(data: ["token": token]) { (error) in
                        if let error = error {
                            print("❌ Could not store notification token in user document: \(error.localizedDescription)")
                            return
                        }
                        print("💰 Added token to user document.")
                    } // addDocument()
                } // getDocuments()
            } // getFirebaseMessagingToken()
        } // knownToken.isEmpty?
    } // func updateNotificationTokens
            
    func removeNotificationToken(completion: @escaping (String?) -> Void) {
        // Get current token
        Permissions.getFirebaseMessagingToken { result in
            var token = ""
            switch result {
            case .success(let fcmToken):
                token = fcmToken
            case .failure(let error):
                completion("❌ Error fetching Firebase instance ID token: \(error)")
                return
            }
            
            print("💸 Removing token: \(token).")
        
            // Find the matching token doc
            let usersDB = Firestore.firestore().collection("users")
            let tokensCollection = usersDB.document(self.uid).collection("notificationTokens")
            let tokenDoc = tokensCollection.whereField("token", isEqualTo: token)
            
            // Fetch the doc
            tokenDoc.getDocuments { snapshot, error in
                guard let snapshot = snapshot else {
                    completion("❌ Failed to fetch user notification tokens: \(error?.localizedDescription ?? "(unknown error)")")
                    return
                }
                
                // If token was found, delete reference from server
                if !snapshot.documents.isEmpty {
                    //                // If there are duplicates of the token (?) and we can't delete them (??), return errors later
                    //                var errors: [Error] = []
                    
//                    // Check that we actually removed the token
//                    var tokenWasRemoved = false
                    
                    // Set up batch of files to delete
                    let batchRemoval = Firestore.firestore().batch()
                    
                    // Queue up delete commands
                    for token in snapshot.documents {
                        batchRemoval.deleteDocument(token.reference)
                    }
                    
                    // Commit the batch
                    batchRemoval.commit() { error in
                        if let error = error {
                            completion("❌ Error deleting token batch: \(error.localizedDescription)")
                            return
                        } else {
                            print("🗑 Removed notification token from user document.")
                            completion(nil)
                        }
                    }
                    
                    //                // Delete anything that matches
                    //                for token in snapshot.documents {
                    //                    token.reference.delete { error in
                    //                        if let error = error {
                    //                            errors.append(error)
                    //                        }
                    //                        print("🗑 Removed notification token from user document.")
                    //                        tokenWasRemoved = true
                    //                    }
                    //                }
                } else {
                    print("⚠️ Token was never found in user's tokens collection.")
                    completion(nil)
                }
                
                
//                // Return errors about any undeletable tokens
//                if !errors.isEmpty {
//                    var allErrors = ""
//                    for number in 1...errors.count {
//                        let error = errors[number - 1].localizedDescription
//                        allErrors += "\(number). \(error)"
//                    }
//                    completion("❌ Error deleting token: \(allErrors)")
////                } else if !tokenWasRemoved {
////                    print("⚠️ Token was never found in user's tokens collection.")
////                    completion(nil)
//                } else {
//                    print("🗑 Removed notification token from user document.")
//                    completion(nil)
//                } // errors.isEmpty?
            } // getDocuments()
        } // getFirebaseMessagingToken()
    } // func removeNotificationToken
    
//    /// Call this when logging in or registering to add push notification token to user doc
//    func updateNotificationTokens(_ knownToken: String = "") {
//        // We can accept the token if it's known, or else look it up
//        var token = ""
//        if !knownToken.isEmpty {
//            token = knownToken
//        } else {
//            // If function was called without a token, fetch it, or give up if we can't
//            Permissions.getFirebaseMessagingToken { (result) in
//                switch result {
//                case .success(let fcmToken):
//                    print("✅ Firebase instance ID token: \(fcmToken)")
//                    token = fcmToken
//                case .failure(let error):
//                    print("❌ Error fetching Firebase instance ID token: \(error)")
//                    return
//                }
//
//                print("💰 Adding token: \(token).")
//
//                // Add/update token subcollection
//                // We wrote a cloud function to take care of removing duplicates from other users when this is done
//                let usersDB = Firestore.firestore().collection("users")
//
//                // First, get user's existing tokens, if applicable
//                usersDB.document(self.uid).getDocument { (snapshot, error) in
//                    guard let snapshot = snapshot,
//                        let data = snapshot.data() else {
//                            let error = error?.localizedDescription ?? "(unknown error)"
//                            print("❌ Failed to fetch user tokens: \(error)")
//                            return
//                    }
//
//                    // Existing tokens, or else empty array
//                    var tokens = data["tokens"] as? [String] ?? []
//
//                    tokens.append(token)
//
//                    // Replace or add array
//                    usersDB.document(self.uid).updateData(["tokens": tokens]) { (error) in
//                        if let error = error {
//                            let error = error.localizedDescription
//                            print("❌ Could not store messaging token in user document: \(error)")
//                            return
//                        }
//                    }
//                    print("💰 Added token to user document.")
//                }
//            }
//        }
//    }
//
//    func removeNotificationToken(completion: @escaping (String?) -> Void) {
//        // Get current token
//        Permissions.getFirebaseMessagingToken { (result) in
//            var token = ""
//            switch result {
//            case .success(let fcmToken):
//                print("✅ Firebase instance ID token: \(fcmToken)")
//                token = fcmToken
//            case .failure(let error):
//                print("❌ Error fetching Firebase instance ID token: \(error)")
//                return
//            }
//
//            print("💰 Removing token: \(token).")
//
//            // Remove from user doc
//            let usersDB = Firestore.firestore().collection("users")
//
//            // First, get user's existing tokens
//            usersDB.document(self.uid).getDocument { (snapshot, error) in
//                guard let snapshot = snapshot,
//                    let data = snapshot.data(),
//                    var tokens = data["tokens"] as? [String] else {
//                    completion("❌ Failed to fetch user tokens: \(error?.localizedDescription ?? "(unknown error)")")
//                    return
//                }
//                tokens.removeAll { $0 == token }
//
//                // Now, replace the array with the token removed
//                usersDB.document(self.uid).updateData(["tokens": tokens]) { (error) in
//                    if let error = error {
//                        completion("❌ Could not store messaging token in user document: \(error)")
//                        return
//                    }
//                    print("🗑 Removed notification token from user profile.")
//                    completion(nil)
//                }
//            }
//        }
//    }
    
    
    
    
//    /// Call this when logging in or registering to add push notification token
//    func updateMessagingToken(_ knownToken: String = "") {
//        // We can accept the token if it's known, or else look it up
//        var token = ""
//        if !knownToken.isEmpty {
//            token = knownToken
//        } else {
//            // If function was called without a token, fetch it, or give up if we can't
//            Permissions.getFirebaseMessagingToken { (result) in
//                switch result {
//                case .success(let fcmToken):
//                    print("✅ Firebase instance ID token: \(fcmToken)")
//                    token = fcmToken
//                case .failure(let error):
//                    print("❌ Error fetching Firebase instance ID token: \(error)")
//                    return
//                }
//
//                print("💰 Adding token: \(token).")
//
//                // Add/update token subcollection
//                // We wrote a cloud function to take care of removing duplicates from other users when this is done
//                UserProfile.addNotificationToken(token, for: user)
//            }
//        }
//    }
    
}
