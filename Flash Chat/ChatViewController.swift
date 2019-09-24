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

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    // MARK: - Properties -
    
    // Messages database
//    // To check if our app isn't so old that we can't safely connect
//    var canConnectToMessagesDB = Version.current.meetsMinimum {
//        didSet { updateForAppVersion() }
//    }
    // "lazy" fixes crash from initializing before AppDelegate configures Firebase
    lazy var messagesDB = Firestore.firestore().collection("messages")
    // Local copy
    var messages = [Message]()
    var messagesToHighlight = [String]()
    // Users (for names and colouring)
    var users = Users()
    
    var colorForUser = [String: UIColor]()
    var oldestMessage: QueryDocumentSnapshot?
    var listeners = [ListenerRegistration]()
    
    // For refreshing timestamps
    var timer = Timer()
    
    // For checking if table should animate while scrolling to bottom
    // Receiving messages rapidly + animation = scrolling doesn't trigger
    private var elapsedTime_: TimeInterval = Date().timeIntervalSinceReferenceDate
    var elapsedTime: TimeInterval {
        let previous = elapsedTime_
        elapsedTime_ = Date().timeIntervalSinceReferenceDate
        return Date().timeIntervalSinceReferenceDate - previous
    }
    
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var messageTextfield: UITextField!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    @IBOutlet weak var composeView: UIView!
    @IBOutlet weak var composeViewBottomConstraint: NSLayoutConstraint!
    
    
    // MARK: - Methods -
    
    // MARK: Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Hide the back button
        navigationItem.hidesBackButton = true
        
        // TableView setup
        messageTableView.delegate = self
        messageTableView.dataSource = self
        
        // Register MessageCell.xib file
        messageTableView.register(UINib(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "customMessageCell")
        
        // TODO: Is this redunant, or is it safe?
//        // See if we need to listen for app meeting minimum version
//        updateForAppVersion()
        Version.current.listen(from: self)
        
        // Watch for keyboard appearing
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Hide the keyboard when the user taps the table view
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        messageTableView.addGestureRecognizer(tapGesture)
        
        // Ask to allow notifications
        // This will only trigger for newly registered users; we get permission for existing users on the first screen
        Permissions.didAsk(for: .notification) { (didAsk) in
            if !didAsk {
                Permissions.ask(for: .notification)
            }
        }
        
        // Load users
        users.fetch() {
            // Change title to user name
            // Note that in debug this must be called after getting users
            self.updateViewTitle()
        }
        
        
        // Load most recent messages and keep observing for new ones
        getRecentMessages(showProgress: true)
        
        // Allow user to pull to refresh
        configureRefreshControl()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !messages.isEmpty {
            startTimer()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer.invalidate()
    }
    
//    func appVersionWasChecked(meetsMinimum: Bool) {
//        print("🐛🐛🐛 updateForAppVersion() called")
//        // We have already received the value
//        if !meetsMinimum {
//            print("🐛🐛🐛 meetsMinimum is false")
//            // Warn user
//            let otherHuds = JGProgressHUD.allProgressHUDs(in: view)
//            otherHuds.forEach { $0.dismiss() }
//            let errorHud = JGProgressHUD()
//            errorHud.indicatorView = JGProgressHUDErrorIndicatorView()
//            errorHud.textLabel.text = "Old Version"
//            errorHud.detailTextLabel.text = "Please update the app."
//            errorHud.dismiss(afterDelay: 3)
//
//            // Disable message textfield and button
//            toggleComposeView(enable: false)
//
//            // TODO: Delete any pending messages
//        }
//        print("🐛🐛🐛 meetsMinimum is true")
//    }
    
//    func updateForAppVersion() {
//        print("🐛🐛🐛 updateForAppVersion() called")
//        // First, check if app minimum version has yet to be identified
//        guard let canUseServer = Version.current.meetsMinimum else {
//            print("🐛🐛🐛 meetsMinimum is nil")
//            return
//        }
////            // TODO: We're waiting on the value, so we'll listen for it
////            NotificationCenter.default.addObserver(self, selector: #selector(updateForAppVersion), name: nil, object: Version.current.meetsMinimum)
////
////            NotificationCenter.default.addObserver(forName: <#T##NSNotification.Name?#>, object: <#T##Any?#>, queue: <#T##OperationQueue?#>, using: <#T##(Notification) -> Void#>)
////
////            NotificationCenter.default.addObserver(<#T##observer: NSObject##NSObject#>, forKeyPath: <#T##String#>, options: <#T##NSKeyValueObservingOptions#>, context: <#T##UnsafeMutableRawPointer?#>)
////            return
////        }
//
////        // Older versions of iOS have to deallocate the observer
////        // I guess we would want to do this on VC's deinit as well...
////        if #available (iOS 9, *) {} else {
////            removeObserver(self, forKeyPath: <#T##String#>)
////        }
//
//        // We have already received the value
//        if !canUseServer {
//            print("🐛🐛🐛 meetsMinimum is false")
//            // Warn user
//            let otherHuds = JGProgressHUD.allProgressHUDs(in: view)
//            otherHuds.forEach { $0.dismiss() }
//            let errorHud = JGProgressHUD()
//            errorHud.indicatorView = JGProgressHUDErrorIndicatorView()
//            errorHud.textLabel.text = "Old Version"
//            errorHud.detailTextLabel.text = "Please update the app."
//            errorHud.dismiss(afterDelay: 3)
//
//            // Disable message textfield and button
//            toggleComposeView(enable: false)
//
//            // TODO: Delete any pending messages
//        }
//        print("🐛🐛🐛 meetsMinimum is true")
//    }
    
    func updateViewTitle() {
        guard let user = Auth.auth().currentUser else {
            fatalError("❌ Can't update view title: No logged in user found!")
        }
        
        if let name = user.displayName {
            navigationItem.title = name
        }
//        } else {
//            // If display name was never set and we're debugging, update the user table
//            #if DEBUG
//            assert(!users.profiles.isEmpty, "🛑 Users object wasn't properly initialized before calling updateViewTitle().")
//            guard let profile = users.profiles.first(where: { $0.id == user.uid }) else {
//                fatalError("❌ Can't update view title: User isn't in users collection!")
//            }
//            let name = profile.name
//            UserProfile.setProfileName(name, for: user, updateUserDocument: false) { (error) in
//                if let error = error {
//                    print("Error adding unset username: \(error).")
//                } else {
//                    print("✅ Added unset username.")
//                }
//            }
//            navigationItem.title = name
//            #else
//                return
//            #endif
//        }
    }
    

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
        colorForUser[message.sender] = messageView.updateUserColor(colorForUser[message.sender])
        
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
    
    func scrollToBottom() {
        let secondLastIndex = messageTableView.numberOfRows(inSection: 0) - 2
        guard let visibleRows = messageTableView.indexPathsForVisibleRows,
            secondLastIndex >= 0 else {
            print("⚠️ Fewer than two rows visible.")
            return
        }
        
        let secondFromBottom: IndexPath = [0, secondLastIndex]
        let bottom: IndexPath = [0, secondLastIndex + 1]
        
        if visibleRows.contains(secondFromBottom) {
            // Scroll to show latest message if we're freshly loading,
            //- or if we're receiving something new while already nearly at the bottom.
            // But kill the animation if we're moving really fast, or it will break
            messageTableView.scrollToRow(at: bottom, at: .bottom, animated: elapsedTime > 0.1)
        } else if messages.last?.sender != Auth.auth().currentUser?.email {
            // Don't scroll if the user has started to go back up
            // Instead, alert them about the new message (unless we were the ones who sent it)
            let hud = JGProgressHUD()
            hud.indicatorView = JGProgressHUDSuccessIndicatorView()
            hud.textLabel.text = "New\nMessage"
            hud.show(in: view)
            hud.dismiss(afterDelay: 0.5)
        }
    }
    
    
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
//        UIView.animate(withDuration: 2.0) {
//            if #available(iOS 13, *) {
//                self.messageTableView.backgroundColor = .systemBackground
//            } else {
//                self.messageTableView.backgroundColor = .white
//            }
//        }
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
    
    // Pagination adopted from: https://medium.com/@650egor/firestore-reactive-pagination-db3afb0bf42e
    
    // TODO: Maybe we don't need the getMessage() method. We can just grab up to the limit the same way as the typical listener, set the last message as oldestMessage, and use the one method to always place the messages at messages[0]; then we can load the view all at once
    //- We still want new (.: also recent) messages to .append() at the bottom instead
    
    // This is used only for the initial (recents+new) load
    func addListenerFromUnknownStart(limit: Int = Int.max, descending: Bool = true, appendToTop: Bool = false, completion: (() -> Void)? = nil) {
        // Query for getRecentMessages
        let query = messagesDB.order(by: "time", descending: descending).limit(to: limit)
        
        query.getDocuments { (snapshot, error) in
            guard let snapshot = snapshot else {
                print("Initialize: Could not listen for messages: \(error?.localizedDescription ?? "(unknown error)")")
                completion?()
                return
            }
            
            // We actually only called this getDocuments to find out the start point
            // The listener for new messages will grab the most recent ones
            
            // The basic query, without a starting bound
            var query = self.messagesDB.order(by: "time")
//            // Exclude any deleted documents (sometimes server is slow)
//            let existingMessages = snapshot.documents.map { $0.exists }
            
            // If there's at least one message, start from the oldest (while respecting limit var)
            if let oldestMessage = snapshot.documents.last {
//                oldestMessage.exists {
                query = query.start(atDocument: oldestMessage)
                self.oldestMessage = oldestMessage
            }
            
            self.addListener(query: query) { completion?() }
            
        }
        
    }
    
    /// Listen for new messages from other clients
    func addListener(query: Query, appendToTop: Bool = false, completion: (() -> Void)? = nil) {
        let listener = query.addSnapshotListener(includeMetadataChanges: true) { (snapshot, error) in
            guard let snapshot = snapshot else {
                print("Listener: Could not listen for messages: \(error?.localizedDescription ?? "(unknown error)")")
                completion?()
                return
            }
            
            // If we're getting the backlog and there's at least one message, save the oldest for reference
            if appendToTop,
                let oldestMessage = snapshot.documents.last {
                self.oldestMessage = oldestMessage
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
            hud.show(in: view)
        }
        // Initial load should grab few of most recent (10, true)
        addListenerFromUnknownStart(limit: 20) {
            if showProgress { hud.dismiss() }
        }
    }
    
    func getOlderMessages(completion: @escaping () -> Void) {
        guard !messages.isEmpty else {
            // There aren't any messages, so start from the beginning
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
        let query = messagesDB.order(by: "time", descending: true).limit(to: 20).start(afterDocument: oldestMessage)
        
        addListener(query: query, appendToTop: true) { completion() }
    }
    
    
    func removeListeners() {
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
//        let sender = Auth.auth().currentUser?.email ?? "(unknown)"
        let sender = Auth.auth().currentUser?.uid ?? "(unknown)"
        let body = willSendMessage(messageTextfield.text ?? "(blank message)")
        let time = FieldValue.serverTimestamp()
        let message = Message.makeDocument(time: time, sender: sender, body: body)
        
        // Add new message to database
        var document: DocumentReference?
        document = messagesDB.addDocument(data: message) { (error) in
            guard let documentID = document?.documentID else {
                print("Failed to send message: \(error?.localizedDescription ?? "unknown error")")
                let spinner = JGProgressHUD()
                spinner.indicatorView = JGProgressHUDErrorIndicatorView()
                spinner.show(in: self.view)
                spinner.dismiss(afterDelay: 0.5)
                // Repopulate text field
                self.messageFailedToSend(body)
                self.toggleComposeView(enable: true)
                return
            }
            print("Saved message using ID \(documentID) (probably to server).")
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
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: [], animations: {
            self.composeViewBottomConstraint.constant = height
            self.view.layoutIfNeeded()
        }, completion: nil)
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
        
        keyboardWillUpdate(height: keyboardHeight)
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        keyboardWillUpdate(height: 0)
    }
    
    @objc func tableViewTapped() {
        messageTextfield.resignFirstResponder()
    }
    

    //////////////////////////////////////////////////////
    
    // MARK: - Segue-related
    
    @IBAction func logOutPressed(_ sender: AnyObject) {
        users.removeListener()
        
        let spinner = JGProgressHUD()
        spinner.show(in: view)
        
        let authorizer = Auth.auth()
        
        guard let user = authorizer.currentUser else {
            fatalError("❌ Tried to sign out while no one was logged in!")
        }
        
        // Remove push notification token from user doc before logging out (need permissions)
        user.removeNotificationToken() { (error) in
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Stop receiving new messages
        removeListeners()
        // And stop looking for app version if we haven't found it
        Version.current.stopListening(from: self)
    }




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


extension ChatViewController: VersionDelegate {
//    var listenerIndex: Int?
    
    func appVersionWasChecked(meetsMinimum: Bool) {
        print("🐛🐛🐛 updateForAppVersion() called")
        guard meetsMinimum else {
            print("🐛🐛🐛 meetsMinimum is false")
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
            
            // TODO: Delete any pending messages
            deletePendingMessages()
            
            return
        }
        print("🐛🐛🐛 meetsMinimum is true")
    }
    
    func deletePendingMessages() {
        // Don't let the server get messages composed with an out-of-date version of the app
//        for listener in listeners {
//            listener
//        }
        
//        Firestore.firestore().clearPersistence { error in
//            if let error = error {
//                print(error.localizedDescription)
//            }
//        }
        
        // The basic query, without a starting bound
        var query = self.messagesDB.order(by: "time")
        
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
