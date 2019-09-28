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
    
    let themeColor = UIColor.systemOrange
    var systemBackgroundColor: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemBackground
            } else {
                return .white
            }
        }
    }
    
    
    // MARK: - Methods

    func construct(using messageView: MessageView, sent: Bool, highlightable: Bool = false) {
        message = messageView
        let message = messageView
        
        if message.sender.isEmpty {
            updateViewForDeleted(highlightable: highlightable)
            return
        }
        
        senderUsername.text = message.sender
        messageBody.text = message.body
        let image = UIImage(named: "egg")
        
        let senderIsSelf = (messageView.message.sender == Auth.auth().currentUser?.uid)
        updateView(senderIsSelf: senderIsSelf, image: image, highlightable: highlightable)
        
        updateTimeLabel()
    }

    private func updateView(senderIsSelf: Bool, image: UIImage?, highlightable: Bool) {
        if senderIsSelf {
            selfImageView.image = image
            senderUsername.isHidden = true
            messageBody.textColor = systemBackgroundColor
        } else {
            avatarImageView.image = image
            avatarImageView.backgroundColor = message?.color
            messageBody.textColor = themeColor
            messageBackground.backgroundColor = systemBackgroundColor
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
//            backgroundColor = .white
            backgroundColor = systemBackgroundColor
        } else {
            backgroundColor = nil
        }
    }
    
    private func updateViewForDeleted(highlightable: Bool) {
        contentView.alpha = 0.5
        
        messageBody.text = "Message deleted."
        messageBackground.backgroundColor = UIColor.systemGray
        messageBody.textColor = systemBackgroundColor
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
        messageBody.textColor = systemBackgroundColor
        
        avatarImageView.isHidden = false
        avatarImageView.image = nil
        selfImageView.image = nil
        
        senderUsername.isHidden = false
        
        // Do not inheret animations when recycling
        // This would cause weird scroll issues, and also throw off keyboard offset
        
    }
    
//    override func awakeFromNib() {
//        super.awakeFromNib()
//        // Initialization code goes here
//    }


}
