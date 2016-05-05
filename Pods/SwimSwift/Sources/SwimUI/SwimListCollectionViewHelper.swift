//
//  SwimListCollectionViewHelper.swift
//  Swim
//
//  Created by Ewan Mellor on 4/12/16.
//
//

import UIKit

private let log = SwimLogging.log


public class SwimListCollectionViewHelper: ListDownlinkDelegate {
    public let listManager = SwimListManager()
    public weak var delegate: SwimListViewHelperDelegate?
    public weak var collectionView: UICollectionView?

    public init() {
        listManager.addDelegate(self)
    }

    public func swimDownlinkDidClose(_: Downlink) {
        SwimAssertOnMainThread()

        collectionView?.reloadData()
    }

    public func swimListDownlink(_: ListDownlink, didInsert _: [SwimModelProtocolBase], atIndexes indexes: [Int]) {
        guard let objectSection = delegate?.swimObjectSection, collectionView = collectionView else {
            return
        }
        let indexPaths = indexes.map { NSIndexPath(forRow: $0, inSection: objectSection) }
        collectionView.insertItemsAtIndexPaths(indexPaths)
    }

    public func swimListDownlink(_: ListDownlink, didMove _: SwimModelProtocolBase, fromIndex: Int, toIndex: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let fromIndexPath = NSIndexPath(forRow: fromIndex, inSection: objectSection)
        let toIndexPath = NSIndexPath(forRow: toIndex, inSection: objectSection)
        collectionView?.moveItemAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }

    public func swimListDownlink(_: ListDownlink, didRemove _: SwimModelProtocolBase, atIndex index: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        collectionView?.deleteItemsAtIndexPaths([indexPath])
    }

    public func swimListDownlink(_: ListDownlink, didUpdate object: SwimModelProtocolBase, atIndex index: Int) {
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
