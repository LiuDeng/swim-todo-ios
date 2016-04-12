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

    public func swimWillChangeObjects() {
        if !firstSync {
            tableView?.beginUpdates()
        }
    }

    public func swimDidChangeObjects() {
        if firstSync {
            log.debug("First sync added \(delegate?.swimObjects.count ?? 0) objects")
            firstSync = false
        }
        else {
            tableView?.endUpdates()
        }
    }

    public func swimDidStopSynching() {
        tableView?.reloadData()
    }

    public func swimDidInsert(object: SwimModelProtocolBase, atIndex index: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        tableView?.insertRowsAtIndexPaths([indexPath], withRowAnimation: (firstSync ? .None : .Fade))
    }

    public func swimDidMove(fromIndex: Int, toIndex: Int) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let fromIndexPath = NSIndexPath(forRow: fromIndex, inSection: objectSection)
        let toIndexPath = NSIndexPath(forRow: toIndex, inSection: objectSection)
        tableView?.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }

    public func swimDidRemove(index: Int, object: SwimModelProtocolBase) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        tableView?.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }

    public func swimDidUpdate(index: Int, object: SwimModelProtocolBase) {
        guard let objectSection = delegate?.swimObjectSection else {
            return
        }
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
