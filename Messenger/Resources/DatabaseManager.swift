//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Nadheer on 28/04/2022.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager {
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }            
            completion(.success(value))
        })
    }
}

//MARK: Account Management

extension DatabaseManager {
    
    public func userExist(with email: String, completion: @escaping ((Bool) -> Void) ) {
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")

        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? String != nil else {
                completion (false)
                return
            }
            completion(true)
        })
    }
    
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                print("Failed to write to database")
                completion(false)
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    let newElement = [
                        "name" : user.firstName + " " + user.lastName,
                        "email" : user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    self.database.child("users").setValue(usersCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    }
                } else {
                    let newCollection: [[String: String]] =
                    [
                        [
                            "name" : user.firstName + " " + user.lastName,
                            "email" : user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    }
                }
            }
            
            completion(true)
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
    /*
     [
         [
             "name":
             "safe_email":
         ],
         [
             "name":
             "safe_email":
         ],
     ]
     */
}
// MARK: Sending messages / conversations
extension DatabaseManager {
    
    ///Create a new conversation with target user email and first message
    public func createNewConversations(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
        let currentName = UserDefaults.standard.value(forKey: "name") as? String else { return }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        let reference = database.child(safeEmail)
        reference.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                return
            }
            
            var message = ""
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let messageDate = firstMessage.sentDate
            
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String : Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "is_read": false,
                    "message": message
                ]
            ]
            
            let recipient_conversationData: [String : Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "is_read": false,
                    "message": message
                ]
            ]
            
            //Update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    conversations.append(recipient_conversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_conversationData])
                }
            })
            
            
            //Update current user conversation entry
            if var conversation = userNode["conversations"] as? [[String: Any]] {
                conversation.append(newConversationData)
                userNode["conversations"] = conversation
                reference.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID, name: name, firstMessage: firstMessage, completion: completion)
                })
            } else {
                userNode["conversations"] = [
                    newConversationData
                ]
                
                reference.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID, name: name, firstMessage: firstMessage, completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation(conversationID: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        let messageDate = firstMessage.sentDate
        
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)

        var message = ""
        switch firstMessage.kind {
            
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }

        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }

        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)

        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": safeEmail,
            "is_read": false,
            "name": name
        ]
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            
            completion(true)
        })
    }
    
    ///Fetches and return all conversations for the user with passed email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap ({ dictionary in
                guard let conversationID = dictionary["id"] as? String,
                let name = dictionary["name"] as? String,
                let otherOtherEmail = dictionary["other_user_email"] as? String,
                let latestMessage = dictionary["latest_message"] as? [String: Any],
                    let date = latestMessage["date"] as? String,
                    let message = latestMessage["message"] as? String,
                    let isRead = latestMessage["is_read"] as? Bool else {
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                            
                return Conversation(id: conversationID, name: name, otherUSerEmail: otherOtherEmail, latestMessage: latestMessageObject)
            })
            
            completion(.success(conversations))
        })
    }
    
    ///Gets all messages for conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap { dictionary in
                guard let name = dictionary["name"] as? String,
                        let isRead = dictionary["is_read"] as? Bool,
                        let content = dictionary["content"] as? String,
                        let messageID = dictionary["id"] as? String,
                        let senderEmail = dictionary["sender_email"] as? String,
                        let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString),
                        let type = dictionary["type"] as? String else {
                    return nil
                }

                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: .text(content))
            }
            
            completion(.success(messages))
        })
    }
    
    ///Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion:  @escaping (Bool) -> Void) {
        
        // add new message to messages
        // update sender latest message
        // update recipient latest message
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snaphot in
            guard let self = self else { return }
            
            guard var currentMessages = snaphot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)

            var message = ""
            switch newMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }

            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }

            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)

            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            
            self.database.child("\(conversation)/messages").setValue(currentMessages, withCompletionBlock: { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                self.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message,
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        var targetConversation: [String: Any]?
                        var position = 0

                        for conversationDictionary in currentUserConversations {
                            if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }

                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                        
                    } else {
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }

                    self.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error , _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        //Update latest message for recipient user
                        
                        self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            var databaseEntryConversations = [[String: Any]]()

                            let updatedValue: [String: Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]

                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                                return
                            }

                            if var otherUserConversations = snapshot.value as? [[String: Any]] {
                                var targetConversation: [String: Any]?
                                var position = 0

                                for conversationDictionary in otherUserConversations {
                                    if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                }

                                if var targetConversation = targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                } else {
                                    // failed to find in current colleciton
                                    let newConversationData: [String: Any] = [
                                        "id": conversation,
                                        "other_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                        "name": currentName,
                                        "latest_message": updatedValue
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }
                            } else {
                                // current collection does not exist
                                let newConversationData: [String: Any] = [
                                    "id": conversation,
                                    "other_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                    "name": currentName,
                                    "latest_message": updatedValue
                                ]
                                databaseEntryConversations = [
                                    newConversationData
                                ]
                            }

                            self.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error , _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                                                
                                completion(true)
                            })
                        })
                    })
                })
            })
        })
    }
    
}
