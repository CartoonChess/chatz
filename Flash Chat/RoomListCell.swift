
//
//  RoomListCell.swift
//  chatz
//
//  Created by Xcode on ’19/09/29.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import UIKit

class RoomListCell: UITableViewCell {
    
    // MARK: - Properties
    
    var preview: RoomPreview? {
        didSet {
            construct()
        }
    }
    
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var unreadCountLabel: PaddedLabel!
    
    // MARK: - Methods
    
//    override func awakeFromNib(_ foo: String) {
//        super.awakeFromNib()
//    }
    
    private func construct() {
        guard let room = preview else {
            print("❌ Room list cell does not have a room preview object.")
            return
        }

        avatarImageView.image = room.icon
        avatarImageView.backgroundColor = preview?.color

        nameLabel.text = room.name
        
        if let message = room.latestMessage, !message.isEmpty {
            messageLabel.text = message
        } else {
            messageLabel.isHidden = true
        }

        if let unreadCount = room.unreadCount,
            unreadCount > 0 {
            unreadCountLabel.text = String(unreadCount)
        } else {
            unreadCountLabel.isHidden = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        avatarImageView.image = nil
        avatarImageView.backgroundColor = nil
        messageLabel.isHidden = false
        unreadCountLabel.isHidden = false
    }

//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//    }

}
