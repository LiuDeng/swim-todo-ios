//
//  SwimMapCollectionViewHelper.swift
//  Swim
//
//  Created by Ewan Mellor on 4/29/16.
//
//

import UIKit

private let log = SwimLogging.log


public class SwimMapCollectionViewHelper: MapDownlinkDelegate {
    public let mapManager = SwimMapManager()

    public weak var delegate: SwimListViewHelperDelegate?
    public weak var collectionView: UICollectionView?

    private let comparator: (SwimModelProtocolBase, SwimModelProtocolBase) -> Bool

    public var sortedObjects = [SwimModelProtocolBase]()

    public init(comparator: (SwimModelProtocolBase, SwimModelProtocolBase) -> Bool) {
        self.comparator = comparator
        mapManager.addDelegate(self)
    }


    public func swimMapDownlink(downlink: MapDownlink, didSet object: SwimModelProtocolBase, forKey key: SwimValue) {
        resortObjects()
    }


    public func swimMapDownlink(downlink: MapDownlink, didRemove object: SwimModelProtocolBase, forKey key: SwimValue) {
        resortObjects()
    }


    public func swimMapDownlinkDidRemoveAll(downlink: MapDownlink, objects: [SwimValue : SwimModelProtocolBase]) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }

        sortedObjects.removeAll()

        let range = (0 ..< objects.count)
        let indexPaths = range.map { NSIndexPath(forItem: $0, inSection: objectSection) }
        collectionView?.deleteItemsAtIndexPaths(indexPaths)
    }


    public func swimMapDownlink(downlink: MapDownlink, didUpdate object: SwimModelProtocolBase, forKey key: SwimValue) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }

        resortObjects()
        let index = indexOf(object)!
        let indexPath = NSIndexPath(forItem: index, inSection: objectSection)
        guard let cell = collectionView?.cellForItemAtIndexPath(indexPath) else {
            return
        }

        if object.isHighlighted == cell.highlighted {
            return
        }

        cell.highlighted = object.isHighlighted
    }


    public func indexOf(object: SwimModelProtocolBase) -> Int? {
        return sortedObjects.indexOf({ $0 === object })
    }


    private func resortObjects() {
        guard let objectSection = delegate?.swimObjectSection, collectionView = collectionView else {
            return
        }

        let newSortedObjects = mapManager.downlink!.objects.values.sort(comparator)

        let diff = Dwifft.diff(sortedObjects, newSortedObjects)

        sortedObjects = newSortedObjects

        let inserts = diff.insertions.map { NSIndexPath(forItem: $0.idx, inSection: objectSection) }
        let deletes = diff.deletions.map { NSIndexPath(forItem: $0.idx, inSection: objectSection) }

        collectionView.performBatchUpdates({ () -> Void in
            collectionView.insertItemsAtIndexPaths(inserts)
            collectionView.deleteItemsAtIndexPaths(deletes)
        }, completion: nil)
    }
}
