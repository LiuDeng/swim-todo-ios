//
//  SwimListCollectionViewHelper.swift
//  Swim
//
//  Created by Ewan Mellor on 4/12/16.
//
//

import UIKit

private let log = SwimLogging.log


public class SwimListCollectionViewHelper: SwimListManagerDelegate {
    public weak var delegate: SwimListViewHelperDelegate?
    public weak var collectionView: UICollectionView?

    public init(listManager: SwimListManagerProtocol) {
        listManager.addDelegate(self)
    }

    public func swimDidStopSynching() {
        collectionView?.reloadData()
    }

    public func swimDidInsert(object: SwimModelProtocolBase, atIndex index: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        collectionView?.insertItemsAtIndexPaths([indexPath])
    }

    public func swimDidMove(fromIndex: Int, toIndex: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let fromIndexPath = NSIndexPath(forRow: fromIndex, inSection: objectSection)
        let toIndexPath = NSIndexPath(forRow: toIndex, inSection: objectSection)
        collectionView?.moveItemAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }

    public func swimDidRemove(index: Int, object: SwimModelProtocolBase) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        collectionView?.deleteItemsAtIndexPaths([indexPath])
    }

    public func swimDidUpdate(index: Int, object: SwimModelProtocolBase) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        guard let cell = collectionView?.cellForItemAtIndexPath(indexPath) else {
            return
        }

        if object.isHighlighted == cell.highlighted {
            return
        }

        cell.highlighted = object.isHighlighted
    }
}
