//
//  ViewController.swift
//  SwapReorderingCollectionViewDemo
//
//  Created by Oleksii Karzov on 11/27/17.
//  Copyright © 2017 olekar. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var collectionView: SwapReorderingCollectionView!
    
    var dataArray = (1...50).map{$0}

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print(dataArray)
        
//        collectionView.isSwapReordering = false
        setupCollectionView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
//        setupCollectionView()
    }
    
    fileprivate func setupCollectionView() {
        let baseSize = collectionView.bounds
        let numberOfCellsInRow = (UIDevice.current.userInterfaceIdiom == .pad) ? 6 : 4
        
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        let emptySpaceInRow = layout.sectionInset.left + layout.sectionInset.right + CGFloat(numberOfCellsInRow - 1) * layout.minimumInteritemSpacing
        let cellWidth = (baseSize.width - emptySpaceInRow) / CGFloat(numberOfCellsInRow)
        layout.itemSize = CGSize(width: cellWidth, height: cellWidth)
        
        collectionView.collectionViewLayout = layout
    }

}

extension ViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        
        if let label = cell.contentView.subviews.first as? UILabel {
            let value = dataArray[indexPath.item]
            
            label.text = "\(value)"
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = dataArray.remove(at: sourceIndexPath.item)
        dataArray.insert(item, at: destinationIndexPath.item)
        
//        print(dataArray)
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
}

extension ViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let longPress = gestureRecognizer as? UILongPressGestureRecognizer else {
            return true
        }
        
        let location = longPress.location(in: collectionView)
        
        if let indexPath = collectionView.indexPathForItem(at: location),
            let cell = collectionView.cellForItem(at: indexPath) {
            return cell.contentView.subviews.first is UILabel
        }
        
        return false
    }
    
    @IBAction func onLongPress(_ sender: UILongPressGestureRecognizer) {
        let location = sender.location(in: collectionView)
        
        switch(sender.state) {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location) else {
                break
            }
            
            let res = collectionView.beginInteractiveMovementForItem(at: indexPath)
            
            print("Dragging for item at index \(indexPath) has started - \(res)")
            
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(location)
            
        case .ended:
            collectionView.updateInteractiveMovementTargetPosition(location)
            collectionView.endInteractiveMovement()
            
            print(dataArray)
            
        default:
            collectionView.cancelInteractiveMovement()
        }
    }
    
}
