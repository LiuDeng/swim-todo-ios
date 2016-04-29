//
//  SwimListTableViewHelper.swift
//  Swim
//
//  Created by Ewan Mellor on 2/16/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit

private let log = SwimLogging.log


public class SwimListTableViewHelper: SwimListManagerDelegate {
    public let listManager: SwimListManagerProtocol
    public var firstSync = true

    /**
     true if this instance has called tableView.beginUpdates() and has not
     yet called tableView.endUpdates().

     This is important if you want to make a call to cellForRowAtIndexPath
     or similar, because you will have to take any pending inserts or
     deletes into account.

     You hopefully don't need to look at this in practice, because
     this class will close any pending table updates if
     swimList(didUpdateObject:) is called, and that's the only time
     I anticipate you needing to call cellForRowAtIndexPath.
     */
    public var insideBeginUpdates = false

    public weak var delegate: SwimListViewHelperDelegate?
    public weak var tableView: UITableView?

    public init(listManager: SwimListManagerProtocol) {
        self.listManager = listManager
        self.listManager.addDelegate(self)
    }

    public func commitEdit(editingStyle: UITableViewCellEditingStyle, indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            listManager.removeObjectAtIndex(indexPath.row)
        }
        else if editingStyle == .Insert {
            listManager.insertNewObjectAtIndex(indexPath.row)
        }
    }

    public func swimListWillChangeObjects(_: SwimListManagerProtocol) {
        if !firstSync {
            precondition(!insideBeginUpdates)
            tableView?.beginUpdates()
            insideBeginUpdates = true
        }
    }

    public func swimListDidChangeObjects(_: SwimListManagerProtocol) {
        if firstSync {
            log.debug("First sync added \(delegate?.swimObjects.count ?? 0) objects")
            firstSync = false
        }
        endUpdatesIfNecessary()
    }

    private func endUpdatesIfNecessary() {
        if insideBeginUpdates {
            insideBeginUpdates = false
            tableView?.endUpdates()
        }
    }

    public func swimListDidStopSynching(_: SwimListManagerProtocol) {
        endUpdatesIfNecessary()
        tableView?.reloadData()
    }

    public func swimList(_: SwimListManagerProtocol, didInsertObjects _: [SwimModelProtocolBase], atIndexes indexes: [Int]) {
        guard let objectSection = delegate?.swimObjectSection, tableView = tableView else {
            return
        }
        let indexPaths = indexes.map { NSIndexPath(forRow: $0, inSection: objectSection) }
        if firstSync {
            UIView.setAnimationsEnabled(false)
            tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
            UIView.setAnimationsEnabled(true)
        }
        else {
            tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Fade)
        }
    }

    public func swimList(_: SwimListManagerProtocol, didMoveObjectFromIndex fromIndex: Int, toIndex: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let fromIndexPath = NSIndexPath(forRow: fromIndex, inSection: objectSection)
        let toIndexPath = NSIndexPath(forRow: toIndex, inSection: objectSection)
        tableView?.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }

    public func swimList(_: SwimListManagerProtocol, didRemoveObject _: SwimModelProtocolBase, atIndex index: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        tableView?.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }

    public func swimList(_: SwimListManagerProtocol, didUpdateObject object: SwimModelProtocolBase, atIndex index: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }

        endUpdatesIfNecessary()

        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        guard let cell = tableView?.cellForRowAtIndexPath(indexPath) else {
            return
        }

        if object.isHighlighted == cell.highlighted {
            return
        }

        cell.setHighlighted(object.isHighlighted, animated: true)
    }
}
