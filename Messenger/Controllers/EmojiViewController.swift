//
//  EmojiViewController.swift
//  Messenger
//
//  Created by Nadheer on 20/07/2022.
//

import UIKit
import RiveRuntime

class EmojiViewController: UIViewController {
    
    let emojis = [
        RiveViewModel(fileName: "emojis", artboardName: "Mindblown"),
        RiveViewModel(fileName: "emojis", artboardName: "Onfire"),
        RiveViewModel(fileName: "emojis", artboardName: "love"),
        RiveViewModel(fileName: "emojis", artboardName: "Bullseye"),
        RiveViewModel(fileName: "emojis", artboardName: "Tada"),
        RiveViewModel(fileName: "emojis", artboardName: "joy")
    ]
    
    private var collectionView: UICollectionView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
    }
    
    override func viewDidLayoutSubviews() {
        collectionView?.frame = view.bounds
    }
    
    func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        
        collectionView.dataSource = self

        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        view.addSubview(collectionView)
        self.collectionView = collectionView
    }
}

extension EmojiViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return emojis.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.backgroundView = emojis[indexPath.row].createRiveView()

        return cell
    }
}
