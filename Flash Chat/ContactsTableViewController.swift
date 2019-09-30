//
//  ContactsTableViewController.swift
//  chatz
//
//  Created by Xcode on ’19/09/29.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import UIKit
import Firebase
import JGProgressHUD

class ContactsTableViewController: UITableViewController {
    
    // MARK: - Properties -
    
    // Users (for names and colouring)
    var users = Users()
    
    // Chats in which we are participating
    var roomsListener: ListenerRegistration?
    var rooms: [RoomPreview] = []
    // Other people in the rooms
//    var participantsListeners: [ListenerRegistration]?
    var participantsListeners: [CollectionReference: ListenerRegistration] = [:]
    // Listeners for individual previews
    var previewListeners: [DocumentReference: ListenerRegistration] = [:]
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var roomSortSwitch: UISwitch!
    
    
    // MARK: - Methods
    
    // MARK: - Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Register MessageCell.xib file
        tableView.register(UINib(nibName: "RoomListCell", bundle: nil), forCellReuseIdentifier: "RoomListCell")
        
        // Version check
        Version.current.listen(from: self)
        
        // Load users
        users.fetch() {
            // Change title to user name
            self.updateViewTitle()
            // Add rows for users without rooms
            self.updateUserCells()
            // Update table
            self.sortRooms()
            // TODO: Show name changes
        }
        
        // Get rooms
        updateRooms()
    }
    
    func updateViewTitle() {
        guard let user = Auth.auth().currentUser else {
            fatalError("❌ Can't update view title: No logged in user found!")
        }
        
        if let name = user.displayName {
            navigationItem.title = name
        }
    }
    
    func updateRooms() {
        guard let userId = Auth.auth().currentUser?.uid else {
            fatalError("❌ Can't fetch user's rooms: No logged in user found!")
        }
        
        let roomsPath = Firestore.firestore().collectionGroup("participants").whereField("uid", isEqualTo: userId)
        roomsListener = roomsPath.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                print("❌ Failed to fetch user rooms: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            print("🐛 We are participating in \(snapshot.documents.count) rooms.")
            for roomChange in snapshot.documentChanges {
                let participantDoc = roomChange.document
                // Get the other participants
                let participantsCollection = participantDoc.reference.parent
                self.participantsListeners[participantsCollection] = participantsCollection.addSnapshotListener { snapshot, error in
                    guard let snapshot = snapshot else {
                        print("❌ Failed to fetch other participants: \(error?.localizedDescription ?? "unknown error")")
                        return
                    }
                    
                    // We'll substitute this below
                    var roomName = "Chat"
                    var otherUserID: String? = nil
                    var otherUserColor: UIColor? = nil
                    
                    let otherParticipants = snapshot.documents.filter { $0.data()["uid"] as? String != userId }
                    switch otherParticipants.count {
                    // If there aren't any, you are alone (essentially deleted chat)
                    case 0:
                        roomName = "Empty Chat"
                    // If there's only one, get your friend's name
                    case 1:
                        // Get other user's name
                        otherUserID = otherParticipants.first?.data()["uid"] as? String
//                        let name = self.users.profiles.first { $0.id == otherUserID }?.name
                        let otherUser = self.users.views.first { $0.user.id == otherUserID }
                        let name = otherUser?.user.name
                        roomName = name ?? roomName
                        // And color
                        otherUserColor = otherUser?.color
                    // If there's more than one, this is a group
                    default:
                        roomName = "Group Chat"
                    }
                    
                    // Get the latest message (for preview)
                    guard let roomDocument = participantsCollection.parent else {
                        print("❌ Couldn't find room document.")
                        return
                    }
                    // To order the rooms dictionary
                    let roomId = roomDocument.documentID
                    
                    // Get the latest document
                    roomDocument.collection("messages").order(by: "time", descending: true).start(at: [Date()]).limit(to: 1).getDocuments { snapshot, error in
                        guard let snapshot = snapshot else {
                            print("❌ Failed to fetch latest room message: \(error?.localizedDescription ?? "unknown error")")
                            return
                        }
                        
                        // Start at the latest message, if there is one
                        // TODO: This won't work if we've got a lot of new messages?
                        var previewQuery = roomDocument.collection("messages").order(by: "time").limit(to: 10)
                        if let newestMessage = snapshot.documents.first {
                            previewQuery = previewQuery.start(atDocument: newestMessage)
                        }
                        
                        // Keep listening for new messages to update the view
                        // TODO: We should only start listening on the first data notification, to avoid adding listeners for every single chat
                        self.previewListeners[roomDocument] = previewQuery.addSnapshotListener { snapshot, error in
                            guard let snapshot = snapshot else {
                                print("❌ Failed to fetch room messages: \(error?.localizedDescription ?? "unknown error")")
                                return
                            }
                            
                            var messageBody: String?
                            var messageTime: Date?
                            if let message = snapshot.documents.last {
                                if let body = message.data()["body"] as? String {
                                    messageBody = body
                                }
                                if let time = message.data()["time"] as? Timestamp {
                                    messageTime = time.dateValue()
                                }
                            }
                            
                            // Create room preview
                            // TODO: Set badge count
                            let icon = UIImage(named: "egg")!
                            let color = otherUserColor ?? UIColor.systemOrange
                            let badge = 0
                            let room = RoomPreview(id: roomId,
                                                   otherUserID: otherUserID,
                                                   name: roomName,
                                                   latestMessage: messageBody,
                                                   latestMessageTime: messageTime,
                                                   icon: icon,
                                                   color: color,
                                                   unreadCount: badge)
                            
                            
                            // See if we're updating a chat row or adding a new one
                            if let index = self.rooms.firstIndex(where: { $0.id == roomId }) {
                                // Chat already exists; update row
                                self.rooms[index] = room
                                self.tableView.reloadRows(at: [[0, index]], with: .automatic)
                            } else {
                                // A new chat has appeared, or we're doing init load
                                self.rooms.append(room)
                                // Add to table
                                let row: [IndexPath] = [[0, self.rooms.count - 1]]
                                self.tableView.insertRows(at: row, with: .automatic)
                            }
                            
                            switch roomChange.type {
                            case .added, .modified:
                                break
                            case .removed:
                                // TODO: Deleted chats
                                return
                            @unknown default:
                                fatalError("🛑 Room's message document changed in an unexpected way!")
                            }
                            
                            self.updateUserCells()
                            self.sortRooms()
                        }
                        
                    }
                }
            }
            
        }
    }
    
    func updateUserCells() {
        for user in users.profiles.filter({ $0.id != Auth.auth().currentUser?.uid }) {
            if !rooms.contains(where: { $0.otherUserID == user.id }) {
                // User is invisible:
                // Create empty cell with username
                showInvisibleUser(user)
            } else if let emptyRoomIndex = rooms.firstIndex(where: { $0.id == user.id }),
                rooms.contains(where: { $0.otherUserID == user.id && $0.id != user.id }) {
                // User already had a visible empty room cell, but a real room with them was created
                // Remove the empty room cell
                removeInvisibleUser(at: emptyRoomIndex)
            }
        }
    }
    
    /// List users with whom we have no associated room
    func showInvisibleUser(_ user: UserProfile) {
        let color = users.views.first { $0.user.id == user.id }?.color ?? UIColor.systemOrange
        let preview = RoomPreview(id: user.id,
                                  otherUserID: user.id,
                                  name: user.name,
                                  latestMessage: nil,
                                  latestMessageTime: nil,
                                  icon: UIImage(named: "egg")!,
                                  color: color,
                                  unreadCount: nil)
        let index = rooms.count
        rooms.append(preview)
        tableView.insertRows(at: [[0, index]], with: .automatic)
    }
    
    /// Get rid of empty room cell when a user gets an active chat
    func removeInvisibleUser(at index: Int) {
        rooms.remove(at: index)
        tableView.deleteRows(at: [[0, index]], with: .automatic)
    }
    

    // MARK: - Table view data source

//    override func numberOfSections(in tableView: UITableView) -> Int {
//        return 1
//    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rooms.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "RoomListCell", for: indexPath) as? RoomListCell else {
            fatalError("🛑 Failed to cast cell as RoomListCell.")
        }

        cell.preview = rooms[indexPath.row]

        return cell
    }
    
    // Apparently we need to do this manually because we're using a nib
    // Note that the segue still exists in the IB
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "RoomSegue", sender: nil)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */
    
    
    // MARK: - Room sorting
    
    /// Switch between sorting alphabetically and sorting with unread messages at the top
    @IBAction func toggleRoomSort(_ sender: UISwitch) {
        sortRooms()
    }
    
    func sortRooms() {
        if roomSortSwitch.isOn {
            sortRoomsByReadStatus()
        } else {
            sortRoomsAlphabetically()
        }
        tableView.scrollToRow(at: [0, 0], at: .none, animated: true)
    }
    
    func sortRoomsByReadStatus() {
        let noTime = Date.distantPast
        
        // Rearrange array
        
        // Unread
        var unread = rooms.filter { $0.unreadCount != nil }
        unread.sort { $0.latestMessageTime ?? noTime > $1.latestMessageTime ?? noTime }
        
        // Read or empty
        let remainder = rooms.filter { $0.unreadCount == nil }
        
        // Read
        var read = remainder.filter { $0.latestMessage != nil }
        read.sort { $0.latestMessageTime ?? noTime > $1.latestMessageTime ?? noTime }
        
        // Empty (alphabetical)
        var empty = remainder.filter { $0.latestMessage == nil }
        empty.sort { $0.name.lowercased() < $1.name.lowercased() }
        
        // Combine
        rooms = unread + read + empty
        
        // Update table
        tableView.reloadData()
    }
    
    func sortRoomsAlphabetically() {
        // Rearrange array
        rooms.sort { $0.name.lowercased() < $1.name.lowercased() }
        
        // Update table
        tableView.reloadData()
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("🔜 Preparing to segue.")
        
        guard let destination = segue.destination as? ChatViewController,
            let cell = tableView.indexPathForSelectedRow else {
            print("❌ Trying to segue to the wrong controller or without a selected row!")
            return
        }
        
        // TODO: Logout segue
        // Stop looking for app version if we haven't found it
        Version.current.stopListening(from: self)
        
        // Get room info
        let room = rooms[cell.row]
        
        // Pass info to room view
        destination.users = users
        destination.roomName = room.name
        
        if room.id != room.otherUserID {
            // This chat already exists
            destination.roomID = room.id
        } else {
            // This is a new chat, without a document ID
            destination.roomID = Firestore.firestore().collection("rooms").document().documentID
            destination.otherUserID = room.otherUserID
        }
    }
    
    
    // MARK: - Deinit
    
    @IBAction func logOutButtonTouched(_ sender: Any) {
        logOut()
    }
    
    func logOut() {
        // Kill room listeners
        removeListeners()
        // Kill user listener
        users.removeListener()
        
        let spinner = JGProgressHUD()
        spinner.show(in: view)
        
        let authorizer = Auth.auth()
        
        guard let user = authorizer.currentUser else {
            fatalError("❌ Tried to sign out while no one was logged in!")
        }
        
        // Remove push notification token from user doc before logging out (need permissions)
        user.removeNotificationToken() { error in
            if let error = error {
                print(error)
                spinner.indicatorView = JGProgressHUDErrorIndicatorView()
                spinner.dismiss(afterDelay: 1)
                return
            } else {
                do {
                    try authorizer.signOut()
                    print("Signed out user \(user.displayName ?? "(name unknown)").")
                    
                    spinner.dismiss()
                    self.performSegue(withIdentifier: "logOutUnwindSegue", sender: self)
                } catch {
                    print("Could not log out: \(error.localizedDescription)")
                    spinner.indicatorView = JGProgressHUDErrorIndicatorView()
                    spinner.dismiss(afterDelay: 1)
                }
            }
        }
    }
    
    func removeListeners() {
        roomsListener?.remove()
        participantsListeners.forEach { $0.1.remove() }
        previewListeners.forEach { $0.1.remove() }
    }

}


extension ContactsTableViewController: VersionDelegate {
    func appVersionWasChecked(meetsMinimum: Bool) {
        if !meetsMinimum {
            // Warn user
            let otherHuds = JGProgressHUD.allProgressHUDs(in: view)
            otherHuds.forEach { $0.dismiss() }
            let errorHud = JGProgressHUD()
            errorHud.indicatorView = JGProgressHUDErrorIndicatorView()
            errorHud.textLabel.text = "Old Version"
            errorHud.detailTextLabel.text = "Please update the app."
            errorHud.show(in: view)
            errorHud.dismiss(afterDelay: 3)
        }
    }
}
