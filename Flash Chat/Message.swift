//
//  Message.swift
//  Flash Chat
//
//  This is the model class that represents the blueprint for a message

import Foundation
import Firebase

class MessageView {
    let message: Message
    
    let id: String?
    let time: Date
    let sender: String // name
    let body: String
    
    var color = UIColor(white: 0, alpha: 1)
    
    init(_ message: Message, users: Users) {
        self.message = message
        
        self.id = message.id
        self.time = message.time
        self.body = message.body
        
        let uid = message.sender
        if uid.isEmpty {
            // Message is deleted
            self.sender = uid
        } else {
            let name = users.profiles.first { $0.id == uid }?.name
            self.sender = name ?? "User"
        }
    }
    
    func updateUserColor(_ color: UIColor?) -> UIColor {
        var color = color
        // Create a new color if we haven't assigned one yet
        if color == nil {
            let red = CGFloat.random(in: 0.0...1.0)
            let green = CGFloat.random(in: 0.0...1.0)
            let blue = CGFloat.random(in: 0.0...1.0)
            color = UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
        // Show in cell
        self.color = color!
        // And keep track in table view controller
        return color!
    }
}

class Message {
    let id: String?
    let time: Date
    let sender: String // uid
    let body: String
    
    // For sending to Firebase
    static func makeDocument(time: FieldValue, sender: String, body: String) -> [String: Any] {
        return [
            "time": time,
            "sender": sender,
            "body": body
        ]
    }
    
    /// Creates an empty message.
    init(deletedID id: String) {
        self.id = id
        self.time = Date()
        self.sender = ""
        self.body = ""
    }
    
    // Native init (time: Date)
    init(time: Date, sender: String, body: String, id: String? = nil) {
        self.time = time
        self.sender = sender
        self.body = body
        self.id = id
    }
    
    // Firebase init (time: Timestamp)
    init(time: Timestamp, sender: String, body: String, id: String? = nil) {
        self.time = time.dateValue()
        self.sender = sender
        self.body = body
        self.id = id
    }
    
    // Object init
    init?(_ values: [String: Any], id: String? = nil) {
        // Get time as Date (native) or TimeInterval (Firebase)
        if let time = values["time"] as? Date {
            self.time = time
        } else if let time = values["time"] as? Timestamp {
            self.time = time.dateValue()
        } else {
            print("Time value incorrectly formatted.")
            return nil
        }
        
        guard let sender = values["sender"] as? String else {
            print("Sender value incorrectly formatted.")
            return nil
        }
        guard let body = values["body"] as? String else {
            print("Body value incorrectly formatted.")
            return nil
        }

        self.sender = sender
        self.body = body
        
        self.id = id
    }
}
