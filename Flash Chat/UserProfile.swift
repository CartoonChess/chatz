//
//  UserProfile.swift
//  Flash Chat
//
//  Created by Xcode on ’19/09/16.
//  Copyright © 2019 Distant Labs. All rights reserved.
//

import Foundation
import Firebase

/// All users we've seen, so we can cache this data
class Users {
    var profiles: [UserProfile]
    private var listener: ListenerRegistration?
    
    // TODO: Later, we would set listeners on friends list and then chatrooms as we visit them
    // This way, we see name changes, but don't have to poll people unimportant to us
    // We have to keep a list of friends and a list of users for each chat, otherwise we poll the entire database
    
    init() {
        self.profiles = []
//        self.listener = ListenerRegistration
    }
    
//    func get(completion: (() -> Void)? = nil) {
//        listener = addListener()
//    }
    
    func removeListener() {
        listener?.remove()
    }
    
    deinit {
        print("🐛 Killing Users object and taking its listener with it.")
        listener?.remove()
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
                    self.profiles.append(user)
                case .modified:
                    guard let user = user else {
                        print("❌ User modified but couldn't create profile from server data.")
                        continue
                    }
                    guard let index = self.profiles.firstIndex(where: { $0.id == id }) else {
                        print("❌ User modified but couldn't find profile in local data.")
                        continue
                    }
                    print("⚠️ User \(user.name) modified.")
                    self.profiles[index] = user
                case .removed:
                    guard let index = self.profiles.firstIndex(where: { $0.id == id }) else {
                        print("❌ User deleted but couldn't find profile in local data.")
                        continue
                    }
                    print("❌ User deleted.")
                    self.profiles.remove(at: index)
                @unknown default:
                    fatalError("User profile changed in an unexpected way!")
                }
            }
            completion?()
        }
        self.listener = listener
    }
    
    // MARK: - Messaging token
    
    // Call this when logging in/registering, to add token and make sure no one else is using it
    static func updateMessagingToken(_ knownToken: String = "", for user: User) {
        // We can accept the token if it's known, or else look it up
        var token = ""
        if !knownToken.isEmpty {
            token = knownToken
        } else {
            // If function was called without a token, fetch it, or give up if we can't
            Permissions.getFirebaseMessagingToken { (result) in
                switch result {
                case .success(let fcmToken):
                    print("✅ Firebase instance ID token: \(fcmToken)")
                    token = fcmToken
                case .failure(let error):
                    print("❌ Error fetching Firebase instance ID token: \(error)")
                    return
                }
                
                print("💰 Adding token: \(token).")
                
                // Add/update token subcollection
                // We can call this at the same time as remove won't remove from self
                UserProfile.addNotificationToken(token, for: user)
            }
        }
    }
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
    
    static func removeMessagingToken(for user: String?, completion: @escaping (String?) -> Void) {
        guard let uid = user else {
            completion("❌ User string is nil.")
            return
        }
        
        // Get current token
        var token = ""
        InstanceID.instanceID().instanceID { (result, error) in
            guard let result = result else {
                completion("❌ Error fetching Firebase instance ID token: \(error?.localizedDescription ?? "(unknown)")")
                return
            }
            token = result.token
            print("✅ Firebase instance ID token: \(token)")
        }
        
        // Remove from user doc
        let usersDB = Firestore.firestore().collection("users")
        
        // First, get user's existing tokens
        usersDB.document(uid).getDocument { (snapshot, error) in
            guard let snapshot = snapshot,
                let data = snapshot.data(),
                var tokens = data["tokens"] as? [String] else {
                completion("❌ Failed to fetch user tokens: \(error?.localizedDescription ?? "(unknown error)")")
                return
            }
            tokens.removeAll { $0 == token }
            
            // Now, replace the array with the token removed
            usersDB.document(uid).updateData(["tokens": tokens]) { (error) in
                if let error = error {
                    completion("❌ Could not store messaging token in user document: \(error)")
                    return
                }
                print("🗑 Removed notification token from user profile.")
                completion(nil)
            }
        }
        
    }
    
}


/// Custom user object representing user info tied to UID
struct UserProfile: Decodable {
    let id: String
    let email: String
    let name: String
//    let id: String?
    
    /// For sending to Firebase to create document
    var document: [String: String] {
        return [
            "email": email,
            "name": name
        ]
    }
    
    static func setProfileName(_ name: String, for user: User, updateUserDocument: Bool = true, completion: @escaping (String?) -> Void) {
        let setNameRequest = user.createProfileChangeRequest()
        setNameRequest.displayName = name
        setNameRequest.commitChanges { (error) in
            if let error = error {
                completion("❌ Error updating users collection: \(error.localizedDescription)")
                return
            }
            
            if updateUserDocument {
                self.updateUserDocument(for: user) { (error) in
                    completion(error)
                }
            } else {
                completion(nil)
            }
        }
    }
    
    /// Add user to users collection, so others can access their profile info
    static func updateUserDocument(for user: User, completion: @escaping (String?) -> Void) {
        guard let name = user.displayName,
            let email = user.email else {
            completion("❌ Couldn't get user name or email to add user document.")
            return
        }
        
        let users = Firestore.firestore().collection("users")
        let uid = user.uid
        let user = UserProfile(id: uid, email: email, name: name)
        // Document ID matches user ID
        users.document(uid).setData(user.document) { (error) in
            if let error = error {
                completion("❌ Error updating users collection: \(error.localizedDescription)")
                return
            }
            print("👋 User profile added to users collection.")
            completion(nil)
        }
    }
    
    static func addNotificationToken(_ token: String, for user: User) {
        let usersDB = Firestore.firestore().collection("users")
        
        // First, get user's existing tokens, if applicable
        usersDB.document(user.uid).getDocument { (snapshot, error) in
            guard let snapshot = snapshot,
                let data = snapshot.data() else {
                    let error = error?.localizedDescription ?? "(unknown error)"
                    print("❌ Failed to fetch user tokens: \(error)")
                    return
            }
            
            // Existing tokens, or else empty array
            var tokens = data["tokens"] as? [String] ?? []
            
            tokens.append(token)
            
            // Replace or add array
            usersDB.document(user.uid).updateData(["tokens": tokens]) { (error) in
                if let error = error {
                    let error = error.localizedDescription
                    print("❌ Could not store messaging token in user document: \(error)")
                    return
                }
            }
            
            print("💰 Added token to user document.")
        }
    }
    
//    /// Before successful registration
//    static func makeDocument(email: String, name: String) -> [String: String] {
//        return [
//            "email": email,
//            "name": name
//        ]
//    }
    
//    /// Init for creating Firebase document
//    init(email: String, name: String, id: String? = nil) {
//        self.email = email
//        self.name = name
//        self.id = id
//    }
    
    /// Init for creating Firebase document
    init(id: String, email: String, name: String) {
        self.id = id
        self.email = email
        self.name = name
    }
    
//    /// For sending to Firebase to create document
//    func document() -> [String: String] {
//        return [
//            "email": email,
//            "name": name
//        ]
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

//    /// Init from Firebase document
//    init?(_ values: [String: String], id: String) {
//        guard let email = values["email"],
//            let name = values["name"] else {
//            print("❌ Problem fetching user email or name.")
//            return nil
//        }
//        self.email = email
//        self.name = name
//        self.id = id
//    }
//
//    /// Experimental init from Firebase JSON
//    init?(_ data: Data) {
//        let decoder = JSONDecoder()
//        do {
//            let fields = try decoder.decode(UserProfile.self, from: data)
//            self.id = fields.id
//            self.email = fields.email
//            self.name = fields.name
//        } catch {
//            print("❌ Problem decoding user profile.")
//            return nil
//        }
//    }
    
}
