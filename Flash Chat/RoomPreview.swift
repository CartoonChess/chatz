//
//  RoomPreview.swift
//  chatz
//
//  Created by Xcode on ’19/09/29.
//  Copyright © 2019 Distant Labs, Inc. All rights reserved.
//

import UIKit

// The model for the cell
struct RoomPreview {
    let id: String
    // This is set when it is not a group chat
    let otherUserID: String?
    
    let name: String
    let latestMessage: String?
    let latestMessageTime: Date?
    
    let icon: UIImage
    let color: UIColor
    
    let unreadCount: Int?
}
