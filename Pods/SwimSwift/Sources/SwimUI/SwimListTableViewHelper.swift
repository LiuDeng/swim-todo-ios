//
//  SwimListTableViewHelper.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/16/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit

private let log = SwimLogging.log


protocol SwimListTableViewHelperDelegate: class {
    var objects: [AnyObject] { get }
    var objectSection: Int { get }
}

class SwimListTableViewHelper: SwimListManagerDelegate {
    let listManager: SwimListManagerProtocol
    var firstSync = true

    weak var delegate: SwimListTableViewHelperDelegate?
    weak var tableView: UITableView?

    init(listManager: SwimListManagerProtocol) {
        self.listManager = listManager
        self.listManager.delegates.append(self)
    }

    func commitEdit(editingStyle: UITableViewCellEditingStyle, indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            listManager.removeObjectAtIndex(indexPath.row)
        }
        else if editingStyle == .Insert {
            listManager.insertNewObjectAtIndex(indexPath.row)
        }
    }

    @objc func swimWillChangeObjects() {
        if !firstSync {
            tableView?.beginUpdates()
        }
    }

    @objc func swimDidChangeObjects() {
        if firstSync {
            log.debug("First sync added \(delegate?.objects.count ?? 0) objects")
            firstSync = false
        }
        else {
            tableView?.endUpdates()
        }
    }

    @objc func swimDidAppend(item: AnyObject) {
        guard let count = delegate?.objects.count, let objectSection = delegate?.objectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: count - 1, inSection: objectSection)
        tableView?.insertRowsAtIndexPaths([indexPath], withRowAnimation: (firstSync ? .None : .Fade))
    }

    @objc func swimDidInsert(object: AnyObject, atIndex index: Int) {
        guard let objectSection = delegate?.objectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        tableView?.insertRowsAtIndexPaths([indexPath], withRowAnimation: (firstSync ? .None : .Fade))
    }

    @objc func swimDidMove(fromIndex: Int, toIndex: Int) {
        guard let objectSection = delegate?.objectSection else {
            return
        }
        let fromIndexPath = NSIndexPath(forRow: fromIndex, inSection: objectSection)
        let toIndexPath = NSIndexPath(forRow: toIndex, inSection: objectSection)
        tableView?.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }

    @objc func swimDidRemove(index: Int, object: AnyObject) {
        guard let objectSection = delegate?.objectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        tableView?.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }

    @objc func swimDidSetHighlight(index: Int, isHighlighted: Bool) {
        guard let objectSection = delegate?.objectSection else {
            return
        }
        let indexPath = NSIndexPath(forRow: index, inSection: objectSection)
        guard let cell = tableView?.cellForRowAtIndexPath(indexPath) else {
            return
        }

        if isHighlighted == cell.highlighted {
            return
        }

        cell.setHighlighted(isHighlighted, animated: true)
    }
}
