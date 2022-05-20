//
//  Conversation.swift
//  Messenger
//
//  Created by Nadheer on 20/05/2022.
//

import Foundation

struct Conversation {
    let id: String
    let name: String
    let otherUSerEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
