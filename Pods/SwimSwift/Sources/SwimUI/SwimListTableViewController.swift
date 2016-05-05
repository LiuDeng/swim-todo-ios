//
//  SwimListTableViewController.swift
//  Swim
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


public class SwimListTableViewController: UITableViewController, SwimListViewHelperDelegate {
    private let tableViewHelper = SwimListTableViewHelper()

    /**
     The Swim objects in this list.

     Equivalent to listManager.objects (this is just an alias for convenience).
     */
    public var swimObjects: [SwimModelProtocolBase] {
        get {
            return swimListManager.objects
        }
    }

    public var swimDownlink: ListDownlink? {
        return swimListManager.downlink
    }

    /**
     The SwimListManager instance that was given to us in the init.
     */
    public var swimListManager: SwimListManager {
        get {
            return tableViewHelper.listManager
        }
    }

    /**
     The section in the UITableView where objects from the Swim list will appear.

     This defaults to 0.  You may set it from your subclass if you want to use
     section 0 for something else.  In that case, you must also override
     all the UITableViewDataSource methods and call SwimListTableViewController's
     implementation of those if and only if the given section is equal to objectSection.
     */
    public var swimObjectSection = 0


    // MARK: Lifecycle

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.tableViewHelper.delegate = self
    }

    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        self.tableViewHelper.delegate = self
    }

    override public func viewDidLoad() {
        tableViewHelper.tableView = tableView
    }

    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        swimListManager.startSynching()
    }

    override public func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        swimListManager.stopSynching()
    }


    // MARK: UITableViewDataSource / UITableViewDelegate

    override public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return swimObjectSection + 1
    }

    override public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        precondition(section == swimObjectSection)
        return swimObjects.count
    }

    override public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        tableViewHelper.commitEdit(editingStyle, indexPath: indexPath)
    }

    override public func tableView(tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
        precondition(indexPath.section == swimObjectSection)
        swimDownlink!.setHighlightAtIndex(indexPath.row, isHighlighted: true)
    }

    override public func tableView(tableView: UITableView, didUnhighlightRowAtIndexPath indexPath: NSIndexPath) {
        precondition(indexPath.section == swimObjectSection)
        swimDownlink!.setHighlightAtIndex(indexPath.row, isHighlighted: false)
    }

    override public func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        precondition(fromIndexPath.section == swimObjectSection && toIndexPath.section == swimObjectSection)
        swimDownlink!.moveFromIndex(fromIndexPath.row, toIndex: toIndexPath.row)
    }

    override public func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}
