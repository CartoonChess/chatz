//
//  ViewController.swift
//  Flash Chat
//
//  Created by Angela Yu on 29/08/2015.
//  Copyright (c) 2015 London App Brewery. All rights reserved.
//

import UIKit
import Firebase
import JGProgressHUD

// Set as a table view so that we can manipulate the back button
protocol ChatViewControllerDelegate {
    /// Notify the contact list that the messages have been read
    func didReadMessages(in roomID: String)
}

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NotificationHandlerDelegate {
    
    // MARK: - Properties -
    
    var delegate: ChatViewControllerDelegate?
    
    // Room collection (room ID and messages collection will be added on later)
//    // "lazy" fixes crash from initializing before AppDelegate configures Firebase
    lazy var messagesDB = Firestore.firestore().collection("rooms")
//    var messagesDB: CollectionReference?
    // Local copy
    var messages = [Message]()
    var messagesToHighlight = [String]()
    // Users (for names and colouring)
    var users = Users()
    // In case we are creating a new chat with someone
    var otherUserID: String?
    
    // Info from the rooms list
    var roomName: String = ""
    var roomID: String = ""
    
//    var colorForUser = [String: UIColor]()
    var oldestMessage: QueryDocumentSnapshot?
    var listeners = [ListenerRegistration]()
    // Avoid downloading too many messages at once
    let messagesToFetch = 20
//    var newMessagesBeforeUpdates = 0
    var cacheIsEmpty = false
    
    // For refreshing timestamps
    var timer = Timer()
    
    // For checking if table should animate while scrolling to bottom
//    // Receiving messages rapidly + animation = scrolling doesn't trigger
//    private var elapsedTime_: TimeInterval = Date().timeIntervalSinceReferenceDate
//    var elapsedTime: TimeInterval {
//        let previous = elapsedTime_
//        elapsedTime_ = Date().timeIntervalSinceReferenceDate
//        return Date().timeIntervalSinceReferenceDate - previous
//    }
    // The updated version:
    // See if user has initiated/completed an upward scroll
    var userDidScrollUp = false
    // Index path of bottom row, or nil if no rows
    var indexPathForBottomRow: IndexPath? {
        let row = messageTableView.numberOfRows(inSection: 0) - 1
        guard row >= 0 else { return nil }
        return IndexPath(row: row, section: 0)
    }
    
    // Keep track of how much the keyboard moved up, so we can scroll the table back down when keyboard disappears
    var messageTableViewOffset: CGFloat = 0
    
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var messageTextfield: UITextField!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    @IBOutlet weak var composeView: UIView!
    @IBOutlet weak var composeViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageTableViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var tableStackView: UIStackView!
    @IBOutlet weak var tableStackViewBottomConstraint: NSLayoutConstraint!
    
    
    // MARK: - Methods -
    
    // MARK: Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // To receive notifications while in the foreground...
        NotificationHandler.current.delegate = self
        
        // TableView setup
        messageTableView.delegate = self
        messageTableView.dataSource = self
        
        // Register MessageCell.xib file
        messageTableView.register(UINib(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "customMessageCell")
        
        // See if we need to listen for app meeting minimum version
        Version.current.listen(from: self)
        
        // Watch for app returning from background
        NotificationCenter.default.addObserver(self, selector:#selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Watch for keyboard appearing
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Hide the keyboard when the user taps the table view
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        messageTableView.addGestureRecognizer(tapGesture)
        
//        // Ask to allow notifications
//        // This will only trigger for newly registered users; we get permission for existing users on the first screen
//        Permissions.didReceivePermission(for: .notification) { didReceive in
//            if didReceive {
//                Permissions.ask(for: .notification)
//            }
//        }
        
        // Update title with chat/user name
        navigationItem.title = roomName
        
        // Determine messages collection path
        messagesDB = messagesDB.document(roomID).collection("messages")
        
        // Load most recent messages and keep observing for new ones
        getRecentMessages(showProgress: true)
        
        // Allow user to pull to refresh
        configureRefreshControl()
    }
    
    /// This will be triggered by AppDelegate
    @objc func didBecomeActive() {
        // Readjust the view, in case the keyboard is showing
        keyboardWillUpdate(height: messageTableViewOffset)
        
        // Remove badges count from contacts list
        delegate?.didReadMessages(in: roomID)
        
        // Update timestamps
        if !messages.isEmpty {
            startTimer()
        }
    }
    
    // NotificationHandler delegate method
    func willPresentNotification(_ notification: UNNotification, options: (UNNotificationPresentationOptions) -> Void) {
        if notification.request.content.threadIdentifier == roomID {
            // Notification is for this chat, so silence it
            options([])
            // Clear plist and let contact list know to ignore notification
            Badges.remove(for: roomID)
            delegate?.didReadMessages(in: roomID)
        } else {
            // Notification is for different chat, so do everything
            options([.alert, .badge, .sound])
        }
    }
    
    func didReceiveTapOnNotification(for roomID: String) {
        // TODO: Implement
    }
    
//    func updateViewTitle() {
//        guard let user = Auth.auth().currentUser else {
//            fatalError("❌ Can't update view title: No logged in user found!")
//        }
//
//        if let name = user.displayName {
//            navigationItem.title = name
//        }
////        } else {
////            // If display name was never set and we're debugging, update the user table
////            #if DEBUG
////            assert(!users.profiles.isEmpty, "🛑 Users object wasn't properly initialized before calling updateViewTitle().")
////            guard let profile = users.profiles.first(where: { $0.id == user.uid }) else {
////                fatalError("❌ Can't update view title: User isn't in users collection!")
////            }
////            let name = profile.name
////            UserProfile.setProfileName(name, for: user, updateUserDocument: false) { (error) in
////                if let error = error {
////                    print("Error adding unset username: \(error).")
////                } else {
////                    print("✅ Added unset username.")
////                }
////            }
////            navigationItem.title = name
////            #else
////                return
////            #endif
////        }
//    }
    

    ///////////////////////////////////////////
    
    // MARK: - Cell
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "customMessageCell", for: indexPath) as? CustomMessageCell else {
            fatalError("Failed to cast cell as CustomMessageCell.")
        }
        
        let message = messages[indexPath.row]
        let messageView = MessageView(message, users: users)
        let messageWasSent = !(message.time == Date(timeIntervalSince1970: 0))
        
//        colorForUser[message.sender] = cell.updateUserColor(colorForUser[message.sender])
//        colorForUser[message.sender] = messageView.updateUserColor(colorForUser[message.sender])
        
        let highlightable = messagesToHighlight.contains(message.id ?? "nil")
        cell.construct(using: messageView,
                       sent: messageWasSent,
                       highlightable: highlightable)
        
//        let message = messages[indexPath.row]
//        let messageWasSent = !(message.time == Date(timeIntervalSince1970: 0))
//
//        colorForUser[message.sender] = cell.updateUserColor(colorForUser[message.sender])
//
//        let highlightable = messagesToHighlight.contains(message.id ?? "nil")
//        cell.construct(using: message,
//                       sent: messageWasSent,
//                       highlightable: highlightable)
        
        return cell
    }
    
    
    // MARK: - Table view methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    
    // MARK: - Scrolling
    
    // Disable scrolling to new messages when user has initiated a scroll
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        userDidScrollUp = true
    }
    
    // This needs to be triggered in case the user dragged without a "flick"
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        userDidScroll()
    }
    
    // Check if last row is showing when user-initiated scroll finishes
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        userDidScroll()
    }
    
    func userDidScroll() {
        guard let bottomRow = indexPathForBottomRow,
            let visibleRows = messageTableView.indexPathsForVisibleRows else {
                print("⚠️ User scroll ended, but table is empty.")
                userDidScrollUp = false
                return
        }
        
        userDidScrollUp = !visibleRows.contains(bottomRow)
    }
    
    func scrollToBottom() {
        guard let bottom = indexPathForBottomRow else {
            print("🛑 scrollToBottom called, but table is empty.")
            return
        }
        
        // The key here is that, if messages come too fast, the bottom row isn't always visible
        // Therefore we need to know if this is due to new messages, or due to user scrolling up
        if !userDidScrollUp {
            // Scroll to show latest message if we're freshly loading,
            //- or if we're receiving something new while at the bottom.
            messageTableView.scrollToRow(at: bottom, at: .bottom, animated: true)
        } else if messages.last?.sender != Auth.auth().currentUser?.uid {
            // Don't scroll if the user has started to go back up
            // Instead, alert them about the new message (unless we were the ones who sent it)
            let hud = JGProgressHUD()
            hud.indicatorView = JGProgressHUDSuccessIndicatorView()
            hud.textLabel.text = "New\nMessage"
//            hud.show(in: view)
            showHUD(hud)
            hud.dismiss(afterDelay: 0.5)
        }
    }
    
//    func scrollToBottom() {
//        let secondLastIndex = messageTableView.numberOfRows(inSection: 0) - 2
//        guard let visibleRows = messageTableView.indexPathsForVisibleRows,
//            secondLastIndex >= 0 else {
//            print("⚠️ Fewer than two rows visible.")
//            return
//        }
//
//        let secondFromBottom: IndexPath = [0, secondLastIndex]
//        let bottom: IndexPath = [0, secondLastIndex + 1]
//
//        if visibleRows.contains(secondFromBottom) {
//            // Scroll to show latest message if we're freshly loading,
//            //- or if we're receiving something new while already nearly at the bottom.
//            // But kill the animation if we're moving really fast, or it will break
//            messageTableView.scrollToRow(at: bottom, at: .bottom, animated: elapsedTime > 0.1)
//        } else if messages.last?.sender != Auth.auth().currentUser?.uid {
//            // Don't scroll if the user has started to go back up
//            // Instead, alert them about the new message (unless we were the ones who sent it)
//            let hud = JGProgressHUD()
//            hud.indicatorView = JGProgressHUDSuccessIndicatorView()
//            hud.textLabel.text = "New\nMessage"
//            hud.show(in: view)
//            hud.dismiss(afterDelay: 0.5)
//        }
//    }
    
    
    // MARK: - Show old messages
    
    func configureRefreshControl() {
        messageTableView.refreshControl = UIRefreshControl()
        messageTableView.refreshControl?.addTarget(self, action: #selector(refreshTableView), for: .valueChanged)
    }
    
    @objc func refreshTableView() {
        print("🏁🏃‍♀️ Begin refresh!")
        messagesToHighlight.removeAll()
        let messagesBeforeUpdate = messages.count
        var didEnd = false
        getOlderMessages() {
            // We only want to perform this once (otherwise it could trigger weird scrolling if messages are modified)
            if !didEnd {
                didEnd.toggle()
                DispatchQueue.main.async {
                    // Dismiss refresh control
                    self.messageTableView.refreshControl?.endRefreshing()
                    // Return table to roughly the same scroll position if older messages were inserted
                    let newMessages = self.messages.count - messagesBeforeUpdate
                    guard newMessages > 0 else { return }
                    let newestOldMessage: IndexPath = [0, newMessages - 1]
                    self.messageTableView.scrollToRow(at: newestOldMessage, at: .top, animated: false)
//                    self.highlightMessages(in: 0...newMessages-1)
                    self.highlightMessages()
                    print("🏁✋ End refresh!")
                }
            }
        }
    }
    
    func highlightMessages() {
        messageTableView.backgroundColor = .systemOrange
        UIView.animate(withDuration: 2.0, delay: 0, options: .allowUserInteraction, animations: {
            if #available(iOS 13, *) {
                self.messageTableView.backgroundColor = .systemBackground
            } else {
                self.messageTableView.backgroundColor = .white
            }
        })
    }
    
    
    ///////////////////////////////////////////
    
    //MARK: - Firebase
    
//    /// Create a new room in the database
//    func createRoom() -> DocumentReference {
//        // Rooms parent path
//        let roomsDB = Firestore.firestore().collection("rooms")
//
//        // Create new room document with dummy data to get doc ID
//        return roomsDB.document()
//    }
    
    // Pagination adopted from: https://medium.com/@650egor/firestore-reactive-pagination-db3afb0bf42e
    
    // This is used only for the initial (recents+new) load
    func addListenerFromUnknownStart(limit: Int = Int.max, descending: Bool = true, appendToTop: Bool = false, completion: (() -> Void)? = nil) {
            // Query for getRecentMessages
            // We must include current time to get the limit-number of messages PLUS any unsent messages
            // This prevents the query from paginating on an unsent message (null time), which will cause a crash
    //        guard let messagesDB = messagesDB else { fatalError("❌ Can't get messagesDB.") }
            let query = messagesDB.order(by: "time", descending: descending).start(at: [Date()]).limit(to: limit)
    //        let query = messagesDB.order(by: "time", descending: descending).limit(to: limit)
            
            query.getDocuments { (snapshot, error) in
                guard let snapshot = snapshot else {
                    print("Initialize: Could not listen for messages: \(error?.localizedDescription ?? "(unknown error)")")
                    completion?()
                    return
                }
                
                // If we're offline and found no cached messages, prevent retrieving all messages once online
                if snapshot.metadata.isFromCache,
                    snapshot.count == 0 {
//                    // Tell the timer to ignore timestamps, and just try for messages again soon
//                    self.startTimer(offline: true)
                    // Wait until we're online to allow sending/receiving
                    self.cacheIsEmpty = true
                    // Don't continue on with the rest until we're online
                    return
                } else {
                    // If we're online after being offline, make sure we stop the timer from refetching messages
                    self.timer.invalidate()
                }
                
                // We actually only called this getDocuments to find out the start point
                // The listener for new messages will grab the most recent ones
                
                // The basic query, without a starting bound
//                // We limit it to the maximum plus one, so we never get too many
//                var query = self.messagesDB.order(by: "time").limit(to: limit + 1)
                var query = self.messagesDB.order(by: "time")
    //            // Exclude any deleted documents (sometimes server is slow)
    //            let existingMessages = snapshot.documents.map { $0.exists }
                
                // If there's at least one message, start from the oldest (while respecting limit var)
                // This should also be ignored if every message is a pending message
                if let oldestMessage = snapshot.documents.last {
                    query = query.start(atDocument: oldestMessage)
                    self.oldestMessage = oldestMessage
                }
                
                self.addListener(query: query) { completion?() }
                
            }
            
        }
//    func addListenerFromUnknownStart(limit: Int = Int.max, descending: Bool = true, appendToTop: Bool = false, completion: (() -> Void)? = nil) {
//        // Query for getRecentMessages
//        // We must include current time to get the limit-number of messages PLUS any unsent messages
//        // This prevents the query from paginating on an unsent message (null time), which will cause a crash
////        guard let messagesDB = messagesDB else { fatalError("❌ Can't get messagesDB.") }
//        let query = messagesDB.order(by: "time", descending: descending).start(at: [Date()]).limit(to: limit)
////        let query = messagesDB.order(by: "time", descending: descending).limit(to: limit)
//
//        query.getDocuments { (snapshot, error) in
//            guard let snapshot = snapshot else {
//                print("Initialize: Could not listen for messages: \(error?.localizedDescription ?? "(unknown error)")")
//                completion?()
//                return
//            }
//
//            // We actually only called this getDocuments to find out the start point
//            // The listener for new messages will grab the most recent ones
//
//            // The basic query, without a starting bound
//            // We limit it to the maximum plus one, so we never get too many
//            var query = self.messagesDB.order(by: "time").limit(to: limit + 1)
////            // Exclude any deleted documents (sometimes server is slow)
////            let existingMessages = snapshot.documents.map { $0.exists }
//
//            // If there's at least one message, start from the oldest (while respecting limit var)
//            // This should also be ignored if every message is a pending message
//            if let oldestMessage = snapshot.documents.last {
//                query = query.start(atDocument: oldestMessage)
//                self.oldestMessage = oldestMessage
//            }
//
//            self.addListener(query: query) { completion?() }
//
//        }
//
//    }
    
    /// Listen for new messages from other clients
    func addListener(query: Query, appendToTop: Bool = false, completion: (() -> Void)? = nil) {
        let listener = query.addSnapshotListener(includeMetadataChanges: true) { (snapshot, error) in
            guard let snapshot = snapshot else {
                print("Listener: Could not listen for messages: \(error?.localizedDescription ?? "(unknown error)")")
                completion?()
                return
            }
            print("🐛🐛🐛 listener snapshot count: \(snapshot.count)")
            if appendToTop,
                let oldestMessage = snapshot.documents.last {
                // If we're getting the backlog and there's at least one message, save the oldest for reference
                self.oldestMessage = oldestMessage
            } else {
                // If we're getting new messages, make sure there aren't too many
                let newMessages = snapshot.documentChanges.filter({ $0.type == .added }).count
                // If there are too many, we need to restart the message fetching process altogether
                if newMessages > self.messagesToFetch {
                    // If we have too many messages, we probably entered a new chat, came in offline, or received a ton
                    // Clear everything and start all over again, using only the latest messages
                    // We'll want to handle this more gracefully in the future
                    print("⚠️ We received a ton of messages! Refreshing the view.")
                    self.removeListeners()
                    self.messages.removeAll()
                    self.messageTableView.reloadData()
                    // Clear the spinner before we start the next operation
                    completion?()
                    self.getRecentMessages(showProgress: true)
                    // Don't continue with display operations below
                    return
                }
//                let messagesAddedSinceViewAppeared = snapshot.documentChanges.filter({ $0.type == .added }).count
//                let newMessages = messagesAddedSinceViewAppeared - self.newMessagesBeforeUpdates
//                self.newMessagesBeforeUpdates = messagesAddedSinceViewAppeared
//                print("🆕 newMessages: \(newMessages)")
//                print("🆕 messagesAddedSinceViewAppeared: \(messagesAddedSinceViewAppeared)")
            }
            // Keep track of how many messages are retrieved from the backlog
            var oldMessages = [IndexPath]()
            
            // We check that the messages actually exists, as the server sometimes feeds IDs of deleted docs
            for change in snapshot.documentChanges(includeMetadataChanges: true) where change.document.exists {
                switch change.type {
                case .added:
                    var data = change.document.data()
                    let id = change.document.documentID
                    
                    // Show local time for newly sent messages (otherwise <null> throws exception)
                    let time = data["time"]
                    if !(time is Date) && !(time is Timestamp) {
//                        data["time"] = Date()
                        data["time"] = Date(timeIntervalSince1970: 0)
//                        // Mark this as a local (unsent) message
//                        self.unsentMessages.append(id)
                        print("⚠️ Changed null-value timestamp to current time.")
                    }
                    
                    guard let message = Message(data, id: id) else {
                        print("❌ Can't convert server's message document to object (ID \(id)).")
//                        self.unsentMessages.removeAll() { $0 == id }
                        continue
                    }
                    // Add to messages array
                    if !appendToTop {
                        // New messages appear at the bottom of the view
                        self.messages.append(message)
                        print("✅ New message received: \"\(message.body)\"")
                        // Update table view
                        let row: [IndexPath] = [[0, self.messages.count - 1]]
                        self.messageTableView.insertRows(at: row, with: .none)
//                        self.messageTableView.insertRows(at: row, with: .right)
                        self.scrollToBottom()
                    } else {
                        // Old messages appear at the top of the view
                        self.messages.insert(message, at: 0)
                        self.messagesToHighlight.append(id)
                        print("📟 Old message received: \"\(message.body)\"")
                        // Prepare to update table view after switch
                        let row = oldMessages.count
                        oldMessages.append([0, row])
                    }
                case .modified:
                    let data = change.document.data()
                    let id = change.document.documentID
                    
                    guard let message = Message(data, id: id) else {
                        print("❌ Can't convert server's message document to object.")
                        continue
                    }
                    print("⚠️ Message modified: \"\(message.body)\"")
                    
                    // Get matching row
                    let possibleRow = self.messages.firstIndex { message in message.id == id }
                    guard let row = possibleRow else {
                        print("❌ No matching row for message found! Maybe we never downloaded it?")
                        continue
                    }
                    
                    // Update arrays
                    self.messages[row] = message
//                    self.unsentMessages.removeAll { $0 == id }
                    
                    // Update table view
                    self.messageTableView.reloadRows(at: [[0, row]], with: .fade)
                case .removed:
                    let id = change.document.documentID
                    print("❌ Document with ID \(id) removed.")
                    
                    // Get matching row
                    let possibleRow = self.messages.firstIndex { message in message.id == id }
                    guard let row = possibleRow else {
                        print("❌ No matching row for message found! Maybe we never downloaded it?")
                        continue
                    }
                    
                    // Make dummy message
                    let message = Message(deletedID: id)
                    
                    // Update arrays
                    self.messages[row] = message
                    
                    // Update table view
                    self.messageTableView.reloadRows(at: [[0, row]], with: .right)
                @unknown default:
                    fatalError("Document changed in a really weird way!")
                }
            }
            
            #if DEBUG
            let deletedDocuments = snapshot.documentChanges(includeMetadataChanges: true).filter { !$0.document.exists }
            if !deletedDocuments.isEmpty {
                let documentIDs = deletedDocuments.map { $0.document.documentID }
                let documents = documentIDs.count.of("deleted document")
                print("\(documents) were found and ignored (IDs: \(documentIDs).")
            }
            #endif
            
            // Update table with backlog all at once, to maintain scroll position
            if appendToTop,
                !oldMessages.isEmpty {
                print("🔝 Appending messages to top now.")
                //                UIView.performWithoutAnimation {
                //                    UIView.setAnimationsEnabled(false)
                //                    self.messageTableView.beginUpdates()
                self.messageTableView.insertRows(at: oldMessages, with: .none)
                //                    self.messageTableView.endUpdates()
                //                    UIView.setAnimationsEnabled(true)
                //                }
            }
            
            // Update timestamps
            self.startTimer()
            
            print("🔥 Firing completion handler")
            completion?()
        }
        
        // Add listener to global array for garbage collection later
        self.listeners.append(listener)
        print("👂 Listener added.")
    }

    
    func getRecentMessages(showProgress: Bool = false) {
        let hud = JGProgressHUD()
        if showProgress {
            // Show a notice when refresh due to too many new messages
            if self.oldestMessage != nil {
//                hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                hud.textLabel.text = "So Many\nNew Messages!"
//                hud.show(in: view)
//                hud.dismiss(afterDelay: 1)
            }
            hud.show(in: view)
        }
        // Initial load should grab few of most recent (10, true)
        addListenerFromUnknownStart(limit: messagesToFetch) {
            if showProgress { hud.dismiss() }
            // If we didn't find any messages, we may have joined an existing chat before passing the version check
            //- If we suddenly connect, we'll be flooded without the limit
            //- Kill the listener, and instruct the version delegate func to restart once online
//            if self.messages.isEmpty {
////                Version.current.meetsMinimum {
//                self.removeListeners()
//            }
        }
    }
    
    func getOlderMessages(completion: @escaping () -> Void) {
        guard !messages.isEmpty else {
            // There aren't any messages, so start from the beginning
            print("⚠️ No messages showing, so look for those first.")
            removeListeners()
            getRecentMessages()
            completion()
            return
        }
        
        guard let oldestMessage = oldestMessage else {
            print("⚠️ There's no backlog.")
            completion()
            return
        }
        
        // Oldest message from previous fetch will now be (just after) our newest message
//        guard let messagesDB = messagesDB else { fatalError("❌ Can't get messagesDB.") }
        let query = messagesDB.order(by: "time", descending: true).limit(to: messagesToFetch).start(afterDocument: oldestMessage)
        
        addListener(query: query, appendToTop: true) { completion() }
    }
    
//    enum FirstListeners {
//        case viewDidLoad, appVersionWasChecked
//    }
//
//    func allFirstListenersDidFinish(including listener: FirstListeners) -> Bool {
//        switch listener {
//        case .viewDidLoad:
//            viewDidLoadListenerAdded = true
//        case .appVersionWasChecked:
//            appVersionWasCheckedListenerAdded = true
//        }
//
//        if viewDidLoadListenerAdded && appVersionWasCheckedListenerAdded {
//            return true
//        } else {
//            return false
//        }
//    }
    
    
    func removeListeners() {
        print("💀 Killing message listeners.")
        // Kill each listener
        listeners.forEach { $0.remove() }
        // Remove dead listeners from array
        listeners.removeAll()
    }
    
    
    // MARK: - Sending messages
    
    @IBAction func textFieldChanged(_ sender: UITextField) {
        sendButton.isEnabled = !(sender.text?.isEmpty ?? true)
    }
    
    @IBAction func sendPressed(_ sender: AnyObject) {
        sendButton.isEnabled = false
        
        // Get message data
        let sender = Auth.auth().currentUser?.uid ?? "(unknown)"
        let body = willSendMessage(messageTextfield.text ?? "(blank message)")
        let time = FieldValue.serverTimestamp()
        let message = Message.makeDocument(time: time, sender: sender, body: body)
        
        var otherUserIDs = [String]()
        if let otherUserID = otherUserID { otherUserIDs.append(otherUserID) }
        
        sendMessage(message, adding: otherUserIDs) { result in
            switch result {
            case .success(let document):
                print("Saved message using ID \(document.documentID).")
            case .failure(let error):
                print("❌ Failed to send message: \(error.localizedDescription)")
                let spinner = JGProgressHUD()
                spinner.indicatorView = JGProgressHUDErrorIndicatorView()
                spinner.show(in: self.view)
                spinner.dismiss(afterDelay: 0.5)
                // Repopulate text field
                self.messageFailedToSend(body)
                self.toggleComposeView(enable: true)
            }
        }
    }
    
    /// Add new message to database
    func sendMessage(_ message: [String: Any], adding participants: [String]? = nil, completion: @escaping (Result<DocumentReference, Error>) -> Void) {
        if let participants = participants,
            !participants.isEmpty {
            
            let spinner = JGProgressHUD()
            spinner.show(in: view)
            
            addParticipants(participants) { result in
                spinner.dismiss()
                switch result {
                case .success(let confirmation):
                    print(confirmation)
                    self.createMessageDocument(from: message) { result in
                        switch result {
                        case .success(let doc):
                            completion(.success(doc))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            createMessageDocument(from: message) { result in
                switch result {
                case .success(let doc):
                    completion(.success(doc))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// If this is the very first message, we must set up the participants list
    func addParticipants(_ userIDs: [String], completion: @escaping (Result<String, Error>) -> Void) {
        guard let roomDoc = messagesDB.parent,
            let currentUserID = Auth.auth().currentUser?.uid else {
            print("❌ Could not access participants collection, or the current user's ID has a problem.")
            return
        }
        let participantsDB = roomDoc.collection("participants")
        
        // Get new write batch
        let batch = Firestore.firestore().batch()
        
        // Create any field in room doc, so it "exists"
        batch.setData(["created": FieldValue.serverTimestamp()], forDocument: roomDoc)
        
        var userIDs = userIDs
        userIDs.append(currentUserID)

        for uid in userIDs {
            batch.setData(["uid": uid], forDocument: participantsDB.document())
        }

        // Commit the batch
        batch.commit() { error in
            if let error = error {
//                print("❌ Error creating participant documents: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                // Once we succeed, make this nil, so we won't try to make it again
                self.otherUserID = nil
                completion(.success("✅ Participant documents created."))
            }
        }
    }
    
    func createMessageDocument(from message: [String: Any], completion: @escaping (Result<DocumentReference, Error>) -> Void) {
        var document: DocumentReference?
        document = messagesDB.addDocument(data: message) { error in
            guard let document = document else {
                let error = error ?? NSError(domain: "", code: 0, userInfo: nil)
                completion(.failure(error))
                return
            }
            completion(.success(document))
        }
    }
    
    func toggleComposeView(enable: Bool) {
        if enable {
            // Send button will still be disabled if textfield is empty
            textFieldChanged(messageTextfield)
        } else {
            sendButton.isEnabled = false
        }
        
        messageTextfield.isEnabled = enable
    }
    
    func willSendMessage(_ message: String) -> String {
        // Clear text field and save message
        messageTextfield.text = ""
        return message
    }
    
    func messageFailedToSend(_ message: String) {
        // Repopulate text field
        if messageTextfield.text == "" {
            messageTextfield.text = message
        }
    }
    
    
    // MARK: - Timestamp timer
    
    func startTimer(interval: TimeInterval = 2.0) {
        // If timer was already set, invalidate it
        timer.invalidate()
        
        // Create timer with default interval
        timer = Timer(fire: Date(timeIntervalSinceNow: interval), interval: 0, repeats: false) { _ in
            // Recreate the timer, but for twice the interval (recursive)
            self.startTimer(interval: interval * 2)
            // Note: Non-repeating timer should invalidate itself
        }
        // This reduces battery usage
        timer.tolerance = interval * 0.1
        // Go
        RunLoop.current.add(timer, forMode: .default)
        
//        // If we haven't come online yet, don't worry about timestamps, just restart message fetch process
//        guard !offline else {
//            getRecentMessages()
//            return
//        }

        // Updating all timestamp labels
        let rowCount = messageTableView.numberOfRows(inSection: 0)
        guard rowCount > 0 else {
            print("⚠️ No rows visible?")
            return
        }
        
        for row in 0...(rowCount-1) {
            let cell = messageTableView.cellForRow(at: [0, row]) as? CustomMessageCell
            cell?.updateTimeLabel()
        }
    }
    
    
    ///////////////////////////////////////////
    
    // MARK: - Keyboard hiding
    
    func keyboardWillUpdate(height: CGFloat) {
//        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: [], animations: {
//            self.composeViewBottomConstraint.constant = height
//        tableStackViewBottomConstraint.constant = height
//            self.offsetTableWithKeyboard(by: height)
       
        // Push the view up or down to match the keyboard
        if height == 0 {
            view.frame.origin.y = height
//            tableStackView.frame.origin.y = height
//            messageTableView.frame.origin.y = height
//            messageTableViewBottomConstraint.constant = 0
//            tableStackViewBottomConstraint.constant = height
        } else {
            view.frame.origin.y -= height
//            tableStackView.frame.origin.y -= height
//            messageTableView.frame.origin.y -= height
//            messageTableViewBottomConstraint.constant = 0
//            tableStackViewBottomConstraint.constant -= height
        }
        
        // Make sure the table doesn't scroll up when there are few messages
        messageTableView.contentInset.top = height
        // Pass keyboard height to view for anything (like hud) that needs to account for change
        messageTableViewOffset = height
        
        self.view.layoutIfNeeded()
//        }, completion: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let userInfoKey = UIResponder.keyboardFrameEndUserInfoKey
        guard let keyboardFrame = notification.userInfo?[userInfoKey] as? NSValue else {
            fatalError("Couldn't get keyboard height.")
        }
        var keyboardHeight = keyboardFrame.cgRectValue.height
        // iPhone X fix
        if #available(iOS 11.0, *) {
            keyboardHeight -= view.safeAreaInsets.bottom
        }
        
        // Prevent this from happening twice in a row
        if view.frame.origin.y == 0 {
            keyboardWillUpdate(height: keyboardHeight)
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if view.frame.origin.y != 0 {
            keyboardWillUpdate(height: 0)
        }
    }
    
    @objc func tableViewTapped() {
        messageTextfield.resignFirstResponder()
    }
    
//    func offsetTableWithKeyboard(by offset: CGFloat) {
//        // This will push the rows up with the keyboard as well
//        messageTableView.contentOffset.y += offset - messageTableViewOffset
//        // This is so it scrolls back down when hiding the keyboard
//        messageTableViewOffset = offset
//    }
    
//    func offsetTableWithKeyboard(by offset: CGFloat) {
////        print("📐 offset (before keyboard): \(messageTableView.contentOffset.y)")
//        // This will push the rows up with the keyboard as well
////        messageTableView.contentOffset.y += offset - messageTableViewOffset
//        let visibleCells = messageTableView.visibleCells.count
//        print("📐 visibleCells: \(visibleCells)")
//        // This is so it scrolls back down when hiding the keyboard
//        messageTableViewOffset = offset
////        print("📐 offset (after keyboard): \(messageTableView.contentOffset.y)")
//
////        if offset > 0 {
////            messageTableView.contentOffset.y += offset
//////            messageTableView.contentInset.bottom = offset
////            messageTableViewOffset = offset
////        } else {
////            messageTableView.contentOffset.y -= messageTableViewOffset
////        }
//
////        if offset == 0 {
////            print("📐 offset (zero): \(offset)")
////            messageTableView.contentInset = .zero
////        } else {
////            print("📐 offset (non-zero): \(offset)")
////            messageTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: offset, right: 0)
////        }
////
////        messageTableView.scrollIndicatorInsets = messageTableView.contentInset
//    }
    
    /// Show the HUD, and adjust it if the view is moved up by the keyboard.
    func showHUD(_ hud: JGProgressHUD) {
        // If the view is pushed up by the keyboard, guess at the new center
        if messageTableViewOffset != 0 {
            let offsetViewVisibleHeight = view.frame.height - messageTableViewOffset
            hud.position = .bottomCenter
//            let hudHeight = hud.hudView.frame.height
            // No good way to calculate this it seems
            let hudHeight: CGFloat = 124.0
            let offset = (offsetViewVisibleHeight - hudHeight) / 2
            hud.layoutMargins.bottom = offset
        }
        
        hud.show(in: view)
    }
    

    //////////////////////////////////////////////////////
    
    // MARK: - Deinit
    
//    @IBAction func logOutPressed(_ sender: AnyObject) {
//        users.removeListener()
//
//        let spinner = JGProgressHUD()
//        spinner.show(in: view)
//
//        let authorizer = Auth.auth()
//
//        guard let user = authorizer.currentUser else {
//            fatalError("❌ Tried to sign out while no one was logged in!")
//        }
//
//        // Remove push notification token from user doc before logging out (need permissions)
//        user.removeNotificationToken() { (error) in
//            if let error = error {
//                print(error)
//                spinner.indicatorView = JGProgressHUDErrorIndicatorView()
//                spinner.dismiss(afterDelay: 1)
//                return
//            } else {
//                do {
//                    try authorizer.signOut()
//                    print("Signed out user \(user.displayName ?? "(name unknown)").")
//
//                    spinner.dismiss()
//                    self.performSegue(withIdentifier: "logOutUnwindSegue", sender: self)
//                } catch {
//                    print("Could not log out: \(error.localizedDescription)")
//                    spinner.indicatorView = JGProgressHUDErrorIndicatorView()
//                    spinner.dismiss(afterDelay: 1)
//                }
//            }
//        }
//    }
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        print("🐛🐛🐛 prepare for segue")
//    }
    
//    deinit {
//        Foreground
//    }
    
    func stopReceivingNotifications() {
        NotificationHandler.current.stopSendingNotifications(to: self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("🐛🐛🐛 viewDidDisappear")
        super.viewDidDisappear(animated)
        // Stop receiving new messages
        removeListeners()
        // And stop looking for app version if we haven't found it
        Version.current.stopListening(from: self)
        // Also kill the timer
        timer.invalidate()
        // And foreground notifications
        stopReceivingNotifications()
    }
    

//    func __getTableSize() {
//        let table = messageTableView!
//        let size = table.contentSize
//        let inset = table.contentInset
//        let offset = table.contentOffset
//        print("🐛🐛🐛 size: \(size)")
//        print("🐛🐛🐛 inset: \(inset)")
//        print("🐛🐛🐛 offset: \(offset)")
//    }
//
//    func __fixSender() {
//        messagesDB.getDocuments { (snapshot, error) in
//            guard let snapshot = snapshot else {
//                print("❌❌❌ \(error!)")
//                return
//            }
//
//            // Get new write batch
//            let batch = Firestore.firestore().batch()
//
//            for docSnap in snapshot.documents {
//                let data = docSnap.data()
//                let docID = docSnap.documentID
//                guard let message = Message(data, id: docID) else {
//                    print("❌❌❌ cant make message")
//                    continue
//                }
//                let email = message.sender
//                let user_ = self.users.profiles.first { $0.email == email }
//                guard let user = user_ else {
//                    print("❌❌ cant find user from email \(email)")
//                    continue
//                }
//                let uid = user.id
//
//                let ref = docSnap.reference
//                batch.setData(["sender": uid], forDocument: ref)
//            }
//
//            // Commit the batch
//            batch.commit() { err in
//                if let err = err {
//                    print("Error writing batch \(err)")
//                } else {
//                    print("Batch write succeeded.")
//                }
//            }
//        }
//    }


//    func __addUsers() {
//        // Add user to users collection
//        let users = Firestore.firestore().collection("users")
//
//        let arrays = [
//            ["hyunah91@hanmail.net", "Hyunah", "1oh5TI0LbJSdSeZggnr2Dt3i25s1"],["your@butt.woo", "Your B.", "Bhsav0ZGYgZsbNPBjmvDiPULuNv2"],["boksung@peach.com", "Boksung", "CW2NtFKgjcPTybnaw9ePWSJyvbl1"],["some@pigmail.org", "Some Pig", "JiNTM1yafwajntsT1jFSJpL669q2"],["asdfasdf@asdf.asdf", "Asdf Asdf", "VmehfWCP7PeYSFcJujwkhP5Risu1"],["asdf@asdf.asdf", "Asdf", "VpnRCrF4ajekqCzZxzw3DaJv6i72"],["6@6.6", "6", "dWPdhSv3nAXPFpa4gNkEnOggfFL2"],["drood@drood.drood", "Drood", "nTW3PHyiXzaxmn8AxgtpLAcl02K3"],["boops@bloops.woop", "Boops", "orBaNchYhgTGkIxgoqhArZBPhw23"]
//        ]
//        //        var usersArray: [UserProfile]
//        //        var refs: [DocumentReference]
//
//        // Get new write batch
//        let batch = Firestore.firestore().batch()
//
//        for i in arrays {
//            //            usersArray.append(UserProfile(id: i[2], email: i[0], name: i[1]))
//            let prof = UserProfile(id: i[2], email: i[0], name: i[1])
//            let ref = users.document(i[2])
//            batch.setData(prof.document, forDocument: ref)
//        }
//
//        // Commit the batch
//        batch.commit() { err in
//            if let err = err {
//                print("Error writing batch \(err)")
//            } else {
//                print("Batch write succeeded.")
//            }
//        }
//    }
//
//    func __callCollectionGroup() {
////        const tokenDocs = await admin.firestore().collectionGroup("notificationTokens").where("token", "==", token).get()
//        var token = ""
//        Permissions.getFirebaseMessagingToken { result in
//            switch result {
//            case .success(let fcmToken):
//                token = fcmToken
//            case .failure(let error):
//                print(error)
//            }
//        }
//
//        Firestore.firestore().collectionGroup("notificationTokens").whereField("token", isEqualTo: token).getDocuments { snapshot, error in
//            if let error = error { print("🐛🐛🐛 __callCollectionGroup error: \(error.localizedDescription)") }
//            if let snapshot = snapshot {
//                print("🐛🐛🐛 __callCollectionGroup found \(snapshot.count) snapshot(s).")
//            }
//        }
//    }


}

// MARK: - Extensions -

extension ChatViewController: VersionDelegate {
    
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
            
            // Disable message textfield and button
            toggleComposeView(enable: false)
            
            // Delete any pending messages
            deletePendingMessages()
        } else if cacheIsEmpty {
            // Restart message fetching process, to avoid retrieving the entire backlog
            // Note that this is flawed logic; if we went offline after doing a version check, the view will never update
            getRecentMessages()
        }
    }
    
    // Don't let the server get messages composed with an out-of-date version of the app
    func deletePendingMessages() {
        // The basic query, without a starting bound
//        guard let messagesDB = messagesDB else { fatalError("❌ Can't get messagesDB.") }
        var query = messagesDB.order(by: "time")
        
        // If there's was at least one message when loading, start from there
        if let oldestMessage = oldestMessage {
            query = query.start(atDocument: oldestMessage)
        }
        
        query.getDocuments { snapshot, error in
            guard let snapshot = snapshot else {
                print("Listener: Could not listen for messages: \(error?.localizedDescription ?? "(unknown error)")")
                return
            }
            
            for document in snapshot.documents {
                if document.metadata.hasPendingWrites {
                    document.reference.delete { error in
                        if let error = error {
                            print("❌ Failed to delete pending message: \(error.localizedDescription)")
                        } else {
                            print("🗑 Pending message deleted.")
                        }
                    }
                }
            }
        }
    }
    
}
