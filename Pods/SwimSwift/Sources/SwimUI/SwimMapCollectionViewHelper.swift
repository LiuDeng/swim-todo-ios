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


    public func downlink(downlink: MapDownlink, didSet object: SwimModelProtocolBase, forKey key: SwimValue) {
        guard let objectSection = delegate?.swimObjectSection, collectionView = collectionView else {
            return
        }

        resortObjects()
        let index = indexOf(object)!
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        collectionView.insertItemsAtIndexPaths([indexPath])
    }


    public func downlink(downlink: MapDownlink, didRemove object: SwimModelProtocolBase, forKey key: SwimValue) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }

        resortObjects()
        let index = indexOf(object)!
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        collectionView?.deleteItemsAtIndexPaths([indexPath])
    }


    public func downlink(downlink: MapDownlink, didUpdate object: SwimModelProtocolBase, forKey key: SwimValue) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }

        resortObjects()
        let index = indexOf(object)!
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        guard let cell = collectionView?.cellForItemAtIndexPath(indexPath) else {
            return
        }

        if object.isHighlighted == cell.highlighted {
            return
        }

        cell.highlighted = object.isHighlighted
    }


    private func indexOf(object: SwimModelProtocolBase) -> Int? {
        return sortedObjects.indexOf({ $0 === object })
    }


    private func resortObjects() {
        sortedObjects = mapManager.downlink!.objects.values.sort(comparator)
    }
}
