//
//  ContactsTableViewController.swift
//  chatz
//
//  Created by Xcode on ’19/09/29.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import UIKit
import Firebase

class ContactsTableViewController: UITableViewController, VersionDelegate {
    
    // MARK: - Properties
    
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
    
    
    // MARK: - Methods
    
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
            // Update view when a new user is added
            self.tableView.reloadData()
            // Add rows for users without rooms
            self.updateUsers()
        }
        
        // Get rooms
        updateRooms()
    }
    
    
    // MARK: - Init
    
    func appVersionWasChecked(meetsMinimum: Bool) {
        // TODO: Do something
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
                                // TODO: Order by name or unread date
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
                        }
                        
                    }
                }
            }
            
        }
    }
    
    /// Create rows for users with whom we have not yet started a room
    func updateUsers() {
        // Remove ourselves from the user list
        var usersWithoutRooms = users.profiles.filter { $0.id != Auth.auth().currentUser?.uid }
        // Then remove users with whom we've already got rooms
        let usersWithRooms = rooms.compactMap { $0.otherUserID }
        usersWithoutRooms = usersWithoutRooms.filter { !usersWithRooms.contains($0.id) }
        
        // Create room preview cells for those users
//        var userPreviews: [RoomPreview] = []
        for user in usersWithoutRooms {
            let color = users.views.first { $0.user.id == user.id }?.color ?? UIColor.systemOrange
            let preview = RoomPreview(id: user.id,
                                      otherUserID: user.id,
                                      name: user.name,
                                      latestMessage: nil,
                                      latestMessageTime: nil,
                                      icon: UIImage(named: "egg")!,
                                      color: color,
                                      unreadCount: nil)
//            userPreviews.append(preview)
            // Update array
            let index = rooms.count
            rooms.append(preview)
            
            // Update the view
            // FIXME: Can this crash if it happens async with updateRooms()?
            tableView.insertRows(at: [[0, index]], with: .automatic)
        }
        
//        // Add these empty chats to the list of real ones
//        rooms += userPreviews
        
        
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
    
    
    
    /// Switch between sorting alphabetically and sorting with unread messages at the top
    @IBAction func toggleRoomSort(_ sender: UISwitch) {
        if sender.isOn {
            sortRoomsByReadStatus()
        } else {
            sortRoomsAlphabetically()
        }
        tableView.scrollToRow(at: [0, 0], at: .none, animated: true)
    }
    
    func sortRoomsByReadStatus() {
        // TODO: Sorted by: Unread:bool->date[->alpha(reuse other func)]
        let noTime = Date.distantPast
        
        // Rearrange array
        // Unread
        var unread = rooms.filter { $0.unreadCount != nil }
        unread.sort { $0.latestMessageTime ?? noTime > $1.latestMessageTime ?? noTime }
        // Read
        var read = rooms.filter { $0.unreadCount == nil }
        read.sort { $0.latestMessageTime ?? noTime > $1.latestMessageTime ?? noTime }
        // Combine
        rooms = unread + read
        
        // Update table
        tableView.reloadData()
    }
    
    func sortRoomsAlphabetically() {
        // Rearrange array
        // TODO: A == a
        rooms.sort { $0.name.lowercased() < $1.name.lowercased() }
        
        // Update table
        tableView.reloadData()
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
        // TODO: Pass Users object to chat view
    }
    
    
    // MARK: - Deinit
    
    func logOut() {
        // TODO: Loutout logic
        removeListeners()
    }
    
    func removeListeners() {
        roomsListener?.remove()
        participantsListeners.forEach { $0.1.remove() }
        previewListeners.forEach { $0.1.remove() }
    }

}
