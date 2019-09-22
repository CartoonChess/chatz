//
//  CustomMessageCell.swift
//  Flash Chat
//
//  Created by Angela Yu on 30/08/2015.
//  Copyright (c) 2015 London App Brewery. All rights reserved.
//

import UIKit
import Firebase

class CustomMessageCell: UITableViewCell {

    // MARK: - Properties

    @IBOutlet var messageBackground: UIView!
    @IBOutlet weak var messageBackgroundTrailing: NSLayoutConstraint!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet weak var selfImageView: UIImageView!
    @IBOutlet var messageBody: UILabel!
    @IBOutlet var senderUsername: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
//    var message: Message?
    var message: MessageView?
    
    let themeColor = UIColor(red: 46.0/255.0, green: 177.0/255.0, blue: 135.0/255.0, alpha: 1)
    
    
    // MARK: - Methods
    
//    func updateUserColor(_ color: UIColor?) -> UIColor {
//        var color = color
//        // Create a new color if we haven't assigned one yet
//        if color == nil {
//            let red = CGFloat.random(in: 0.0...1.0)
//            let green = CGFloat.random(in: 0.0...1.0)
//            let blue = CGFloat.random(in: 0.0...1.0)
//            color = UIColor(red: red, green: green, blue: blue, alpha: 1)
//        }
//        // Show in cell
//        avatarImageView.backgroundColor = color
//        // And keep track in table view controller
//        return color!
//    }

    func construct(using messageView: MessageView, sent: Bool, highlightable: Bool = false) {
//    func construct(using message: Message, sent: Bool, highlightable: Bool = false) {
//    func construct(using message: Message, sent: Bool, messageBodyColor: UIColor, highlightable: Bool = false) {
//        self.message = message
        message = messageView
        let message = messageView
        
        if message.sender.isEmpty {
            updateViewForDeleted(highlightable: highlightable)
            return
        }
        
        senderUsername.text = message.sender
        messageBody.text = message.body
        let image = UIImage(named: "egg")
        
//        let senderIsSelf = (message.sender == Auth.auth().currentUser?.email)
        let senderIsSelf = (messageView.message.sender == Auth.auth().currentUser?.uid)
//        updateView(senderIsSelf: senderIsSelf, image: image, color: messageBodyColor, highlightable: highlightable)
        updateView(senderIsSelf: senderIsSelf, image: image, highlightable: highlightable)
        
        updateTimeLabel()
    }

    private func updateView(senderIsSelf: Bool, image: UIImage?, highlightable: Bool) {
//    private func updateView(senderIsSelf: Bool, image: UIImage?, color: UIColor, highlightable: Bool) {
        if senderIsSelf {
            selfImageView.image = image
            senderUsername.isHidden = true
//            messageBody.textColor = themeColor
//            messageBackground.backgroundColor = .white
        } else {
            avatarImageView.image = image
//            avatarImageView.backgroundColor = color
            avatarImageView.backgroundColor = message?.color
            messageBody.textColor = themeColor
            messageBackground.backgroundColor = .white
        }
        
        // Toggle visibility
        selfImageView.isHidden = !senderIsSelf
        avatarImageView.isHidden = senderIsSelf
        
        messageBody.textAlignment = alignText(senderIsSelf: senderIsSelf)
        timeLabel.textAlignment = alignText(senderIsSelf: senderIsSelf)
        
        isHighlightable(highlightable)
    }
    
    private func alignText(senderIsSelf: Bool) -> NSTextAlignment {
        return senderIsSelf ? .right : .left
    }
    
    func updateTimeLabel() {
        // Don't update if message is deleted
        guard let message = message,
            !message.sender.isEmpty else { return }
        
        if message.time == Date(timeIntervalSince1970: 0) {
            timeLabel.text = "sending…"
        } else {
            timeLabel.text = message.time.readable(style: .elapsed)
        }
    }
    
    private func isHighlightable(_ highlightable: Bool) {
        if !highlightable {
            backgroundColor = .white
        } else {
            backgroundColor = nil
        }
    }
    
    private func updateViewForDeleted(highlightable: Bool) {
        contentView.alpha = 0.5
        
        messageBody.text = "Message deleted."
        messageBackground.backgroundColor = UIColor(white: 0.25, alpha: 1)
        messageBody.textColor = .white
        messageBody.textAlignment = .center
        
        selfImageView.isHidden = true
        avatarImageView.isHidden = true
        
        senderUsername.text = nil
        timeLabel.text = nil
    }
    
    // Clears up any aesthetic changes to a cell before reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.alpha = 1
        
        messageBackground.backgroundColor = themeColor
        messageBody.textColor = .white
        
        avatarImageView.isHidden = false
        avatarImageView.image = nil
        selfImageView.image = nil
        
        senderUsername.isHidden = false
    }
    
//    override func awakeFromNib() {
//        super.awakeFromNib()
//        // Initialization code goes here
//    }


}
