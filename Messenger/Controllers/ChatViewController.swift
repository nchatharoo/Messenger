//
//  ChatViewController.swift
//  Messenger
//
//  Created by Nadheer on 03/05/2022.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import AVFoundation
import AVKit
import CoreLocation

public struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}

extension MessageKind {
    var messageKindString: String {
        switch self {
            
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributedText"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "linkPreview"
        case .custom(_):
            return "custom"
        }
    }
}

public struct Sender: SenderType {
    var photoURL: String
    public var senderId: String
    public var displayName: String
}

struct Media: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Location: LocationItem {
    var location: CLLocation
    var size: CGSize
}

class ChatViewController: MessagesViewController {
    
    public static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = Locale.init(identifier: "en_US")
        return formatter
    }()
    
    public var isNewConversation = false
    public let otherUserEmail: String
    private let conversationID: String?
    
    private var messages = [Message]()
    
    private lazy var selfSender: Sender? = {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "",
                      senderId: safeEmail,
                      displayName: "Me")
    }()
    
    init(with email: String, id: String?) {
        self.otherUserEmail = email
        self.conversationID = id
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach media", message: "What would you like to attach", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] result in
            self?.presentPhotoInputActionSheet()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] result in
            self?.presentVideoInputActionSheet()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: { [weak self] result in
            
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self] result in
            self?.presentLocationPicker()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] result in
        }))
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Pick location"
        vc.isPickable = true
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinates in
            guard let self = self else { return }
            guard let messageID = self.createMessageID(),
                  let conversationID = self.conversationID,
                  let name = self.title,
                  let sender = self.selfSender else { return }

            let latitude: Double = selectedCoordinates.latitude
            let longitude: Double = selectedCoordinates.longitude
            
            print(latitude, longitude)
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: .zero)
            
            let message = Message(
                sender: sender,
                messageId: messageID,
                sentDate: Date(),
                kind: .location(location))
            
            DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: self.otherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print("sent location")
                } else {
                    print("failed to sent location")
                }
            })

        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach photo", message: "What would you like to attach a photo from", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] result in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] result in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true, completion: nil)

    }
    
    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach video", message: "What would you like to attach a video from", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] result in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] result in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true, completion: nil)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationID = conversationID {
            listenForMessages(id: conversationID, shouldScrollToBottom: true)
        }
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else { return }
                
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToBottom()
                    }
                }
                
            case .failure(let error):
                print(error)
            }
        })
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let messageID = createMessageID(),
                let conversationID = conversationID,
                let name = self.title,
                let sender = selfSender else { return }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            //        upload photo
            //        send Message
            let fileName = "photo_message_" + messageID.replacingOccurrences(of: " ", with: "-") + ".png"
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let urlString):
                    print("Uploaded message photo \(urlString)")
                    
                    guard let url = URL(string: urlString), let placeholder = UIImage(systemName: "plus") else { return }
                    
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    
                    let message = Message(
                        sender: sender,
                        messageId: messageID,
                        sentDate: Date(),
                        kind: .photo(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: self.otherUserEmail, name: name, newMessage: message, completion: { success in
                        
                    })
                case .failure(let error):
                    print(error)
                }
            })

        } else if let videoURL = info[.mediaURL] as? URL {
            //        upload video
            //        send Message

            let fileName = "video_message_" + messageID.replacingOccurrences(of: " ", with: "-") + ".mov"

            StorageManager.shared.uploadMessageVideo(with: videoURL, fileName: fileName, completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let urlString):
                    print("Uploaded message video \(urlString)")
                    
                    guard let url = URL(string: urlString), let placeholder = UIImage(systemName: "plus") else { return }
                    
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    
                    let message = Message(
                        sender: sender,
                        messageId: messageID,
                        sentDate: Date(),
                        kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: self.otherUserEmail, name: name, newMessage: message, completion: { success in
                        
                    })
                case .failure(let error):
                    print(error)
                }
            })
        }
        
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty, let sender = selfSender, let messageID = createMessageID() else { return }
        let message = Message(
            sender: sender,
            messageId: messageID,
            sentDate: Date(),
            kind: .text(text))
        
        
        if isNewConversation {
            DatabaseManager.shared.createNewConversations(with: otherUserEmail, name: self.title ?? "user", firstMessage: message, completion: { [weak self] success in
                if success {
                    self?.isNewConversation = false
                } else {
                    print("Failed to sent")
                }
            })
        } else {
            guard let conversationID = conversationID, let name = self.title else { return }
            
            DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: otherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print("message sent")
                } else {
                    print("failed to sent")
                }
            })
            
        }
    }
    
    private func createMessageID() -> String? {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeEmail)_\(dateString)"
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else { return }
        
        switch message.kind {
            
        case .photo(let media):
            guard let imageURL = media.url else { return }
            imageView.sd_setImage(with: imageURL, completed: nil)
            
        default: break
        }
    }
}

extension ChatViewController: MessageCellDelegate {
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
            
        case .photo(let media):
            guard let imageURL = media.url else { return }

            let vc = PhotoViewerViewController(with: imageURL)
            
            self.navigationController?.pushViewController(vc, animated: true)
            
        case .video(let media):
            guard let videoURL = media.url else { return }

            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoURL)
            vc.player?.play()
            present(vc, animated: true)
            
        default: break
        }
    }
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
            
        case .location(let location):
            let coordinates = location.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            self.navigationController?.pushViewController(vc, animated: true)
                        
        default: break
        }

    }
}
