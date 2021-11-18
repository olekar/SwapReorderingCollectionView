//
//  SwapReorderingCollectionView.swift
//  SwapReorderingCollectionViewDemo
//
//  Created by Oleksii Karzov on 11/27/17.
//  Copyright © 2017 olekar. All rights reserved.
//

import UIKit


public typealias SwapReorderingCollectionViewAnimationDataSource = (UICollectionView, IndexPath, UIView, (()->Void)?) -> Void


public class SwapReorderingCollectionView: UICollectionView {
    
    // MARK: public ivars
    
    public var isSwapReordering = true
    
    public var maxScrollingSpeed: UInt = 500
    public var scrollInsets: UIEdgeInsets?
    
    public var createViewForInteractiveMovement: (UICollectionView, IndexPath) -> UIView = {
        return { collectionView, indexPath in
            let imageView = UIImageView()
            
            if let cell = collectionView.cellForItem(at: indexPath) {
                UIGraphicsBeginImageContextWithOptions(cell.bounds.size, false, 0)
                cell.layer.render(in: UIGraphicsGetCurrentContext()!)
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                imageView.image = image
                imageView.frame = cell.frame
            }
            
            return imageView
        }
    }()
    
    public var beginInteractiveMovementAnimation: SwapReorderingCollectionViewAnimationDataSource = {
        return { collectionView, indexPath, interactiveView, completion in
            UIView.animate(withDuration: 0.2, animations: {
                interactiveView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }, completion: { (finished) in
                completion?()
            })
            } as SwapReorderingCollectionViewAnimationDataSource
    }()
    
    public var finishInteractiveMovementAnimation: SwapReorderingCollectionViewAnimationDataSource = {
        return { collectionView, indexPath, interactiveView, completion in
            if let frame = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame {
                UIView.animate(withDuration: 0.2, animations: {
                    interactiveView.transform = CGAffineTransform.identity
                    interactiveView.center = CGPoint(x: frame.origin.x + frame.size.width / 2,
                                                     y: frame.origin.y + frame.size.height / 2)
                }) { (finished) in
                    completion?()
                }
            } else {
                completion?()
            }
            } as SwapReorderingCollectionViewAnimationDataSource
    }()
    
    // MARK: private ivars
    
    fileprivate var interactiveCellIndexPath : IndexPath?
    
    fileprivate var interactiveView : UIView?
    
    fileprivate var scrollingSpeed = CGPoint.zero
    fileprivate var displayLink: CADisplayLink?
    
    // MARK: override
    
    override public var contentOffset: CGPoint {
        didSet {
            // New position of interactiveView has to be calculated here because contentOffset can be changed from outside
            // For example, after resetting collectionViewLayout
            if let currentPosition = interactiveView?.center {
                let contentOffsetChange = CGPoint(x: contentOffset.x - oldValue.x, y: contentOffset.y - oldValue.y)
                let newPosition = CGPoint(x: currentPosition.x + contentOffsetChange.x, y: currentPosition.y + contentOffsetChange.y)
                
                changeInteractiveViewPosition(to: newPosition)
            }
        }
    }
    
    override public func dequeueReusableCell(withReuseIdentifier identifier: String, for indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        
        if let interactiveCellIndexPath = interactiveCellIndexPath {
            cell.isHidden = (indexPath == interactiveCellIndexPath)
        } else {
            cell.isHidden = false
        }
        
        return cell
    }
    
    override public func beginInteractiveMovementForItem(at indexPath: IndexPath) -> Bool {
        guard isSwapReordering else {
            return super.beginInteractiveMovementForItem(at: indexPath)
        }
        
        if let canMove = dataSource?.collectionView?(self, canMoveItemAt: indexPath), canMove == false {
            return false
        }
        
        guard interactiveCellIndexPath == nil else {
            return false
        }
        
        interactiveCellIndexPath = indexPath
        
        interactiveView = createViewForInteractiveMovement(self, indexPath)
        addSubview(interactiveView!)
        bringSubviewToFront(interactiveView!)
        
        beginInteractiveMovementAnimation(self, indexPath, interactiveView!, nil)
        
        let interactiveCell = cellForItem(at: indexPath)
        interactiveCell?.isHidden = true
        
        return true
    }
    
    override public func updateInteractiveMovementTargetPosition(_ targetPosition: CGPoint) {
        guard interactiveCellIndexPath != nil else {
            return super.updateInteractiveMovementTargetPosition(targetPosition)
        }
        
        changeInteractiveViewPosition(to: targetPosition)
    }
    
    override public func endInteractiveMovement() {
        guard interactiveCellIndexPath != nil else {
            return super.endInteractiveMovement()
        }
        
        finishMovement()
    }
    
    override public func cancelInteractiveMovement() {
        guard interactiveCellIndexPath != nil else {
            return super.cancelInteractiveMovement()
        }
        
        finishMovement()
    }
    
    // MARK: private
    
    fileprivate func changeInteractiveViewPosition(to targetPosition: CGPoint) {
        guard let interactiveView = interactiveView else {
            cleanup()
            return
        }
        
        interactiveView.center = targetPosition
        
        reorderIfNeeded()
        scrollIfNeeded()
    }
    
    fileprivate func finishMovement() {
        if let interactiveCellIndexPath = interactiveCellIndexPath,
            let interactiveView = interactiveView {
            finishInteractiveMovementAnimation(self, interactiveCellIndexPath, interactiveView, { [weak self] in
                self?.cleanup()
            })
        } else {
            cleanup()
        }
    }
    
    fileprivate func cleanup() {
        if let interactiveCellIndexPath = interactiveCellIndexPath,
            let cell = cellForItem(at: interactiveCellIndexPath) {
            cell.isHidden = false
        }
        
        interactiveView?.removeFromSuperview()
        interactiveView = nil
        
        interactiveCellIndexPath = nil
        
        displayLink?.invalidate()
        displayLink = nil
    }
    
}

// MARK: - reordering

extension SwapReorderingCollectionView {
    
    fileprivate func reorderIfNeeded() {
        guard let interactiveView = interactiveView,
            let currentIndexPath = interactiveCellIndexPath,
            let newIndexPath = indexPathForItem(at: interactiveView.center),
            currentIndexPath != newIndexPath else {
                return
        }
        
        notifyDataSourcesTo(swapItemAt: currentIndexPath, withItemAt: newIndexPath)
        self.interactiveCellIndexPath = newIndexPath
        
        performBatchUpdates({
            self.moveItem(at: currentIndexPath, to: newIndexPath)
            self.moveItem(at: newIndexPath, to: currentIndexPath)
        }, completion: {(finished) in
            
        })
    }
    
    fileprivate func notifyDataSourcesTo(swapItemAt indexPath1: IndexPath, withItemAt indexPath2: IndexPath) {
        dataSource?.collectionView?(self, moveItemAt: indexPath1, to: indexPath2)
        
        if indexPath1.section != indexPath2.section {
            let newIndexPath = IndexPath(item: indexPath2.item + 1, section: indexPath2.section)
            dataSource?.collectionView?(self, moveItemAt: newIndexPath, to: indexPath1)
        } else {
            if indexPath1.item < indexPath2.item &&
                (indexPath1.item != indexPath2.item + 1 && indexPath1.item != indexPath2.item - 1) {
                let newIndexPath = IndexPath(item: indexPath2.item - 1, section: indexPath2.section)
                dataSource?.collectionView?(self, moveItemAt: newIndexPath, to: indexPath1)
            } else if indexPath1.item > indexPath2.item &&
                (indexPath2.item != indexPath1.item + 1 && indexPath2.item != indexPath1.item - 1) {
                let newIndexPath = IndexPath(item: indexPath2.item + 1, section: indexPath2.section)
                dataSource?.collectionView?(self, moveItemAt: newIndexPath, to: indexPath1)
                
            }
        }
    }
    
}


// MARK: - scrolling

extension SwapReorderingCollectionView {
    
    fileprivate func scrollIfNeeded() {
        guard let interactiveView = interactiveView else {
            cleanup()
            return
        }
        
        let currentPosition = interactiveView.center
        let interactiveViewBounds = interactiveView.bounds
        let scrollInset: UIEdgeInsets = scrollInsets ?? UIEdgeInsets(top: interactiveViewBounds.height / 2,
                                                                     left: interactiveViewBounds.width / 2,
                                                                     bottom: interactiveViewBounds.height / 2,
                                                                     right: interactiveViewBounds.width / 2)
        let maxScrollingSpeed = CGFloat(self.maxScrollingSpeed)
        var newScrollingSpeed = CGPoint.zero
        let eps: CGFloat = 0.001
        
        if abs(bounds.size.width - contentSize.width) > eps {
            if currentPosition.x < contentOffset.x + eps + scrollInset.left &&
                contentOffset.x > 0 + eps {
                newScrollingSpeed.x = -maxScrollingSpeed
            } else if currentPosition.x > contentOffset.x + bounds.size.width - eps - scrollInset.right &&
                contentOffset.x < contentSize.width - bounds.size.width - eps {
                newScrollingSpeed.x = maxScrollingSpeed
            }
        }
        
        if abs(bounds.size.height - contentSize.height) > eps {
            if currentPosition.y < contentOffset.y + eps + scrollInset.top &&
                contentOffset.y > 0 + eps {
                newScrollingSpeed.y = -maxScrollingSpeed
            } else if currentPosition.y > contentOffset.y + bounds.size.height - eps - scrollInset.bottom &&
                contentOffset.y < contentSize.height - bounds.size.height - eps {
                newScrollingSpeed.y = maxScrollingSpeed
            }
        }
        
        scrollingSpeed = newScrollingSpeed
        
        if newScrollingSpeed.equalTo(CGPoint.zero) {
            displayLink?.invalidate()
            displayLink = nil
        } else if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink(_:)))
            displayLink?.add(to: RunLoop.main, forMode: .common)
        }
    }
    
    @objc fileprivate func onDisplayLink(_ displayLink: CADisplayLink) {
        guard interactiveView != nil else {
            cleanup()
            return
        }
        
        let translation = CGPoint(x: scrollingSpeed.x * CGFloat(displayLink.duration), y: scrollingSpeed.y * CGFloat(displayLink.duration))
        
        var newContentOffset = CGPoint(x: contentOffset.x + translation.x, y: contentOffset.y + translation.y)
        newContentOffset.x = max(0, min(contentSize.width - bounds.size.width, newContentOffset.x))
        newContentOffset.y = max(0, min(contentSize.height - bounds.size.height, newContentOffset.y))
        
        contentOffset = newContentOffset
    }
    
}
