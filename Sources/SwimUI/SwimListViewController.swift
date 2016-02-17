//
//  SwimListViewController.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/16/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit

import Recon
import Swim


/**
 To use this class:

 1. Subclass it with your own view controller.
 2. Set swimListTableView equal to the correct on-screen UITableView
    in your viewDidLoad.  This will register the Swim list with the
    given UITableView, including setting its dataSource and delegate
    to refer to this instance of SwimListViewController.
 3. Implement cellForRowAtIndexPath as normal (overriding the
    fake implementation here).
 */
public class SwimListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SwimListTableViewHelperDelegate {
    private let tableViewHelper: SwimListTableViewHelper

    /**
     The Swim objects in this list.

     Equivalent to listManager.objects (this is just an alias for convenience).
     */
    public var objects: [AnyObject] {
        get {
            return listManager.objects
        }
    }

    /**
     The SwimListManager instance that was given to us in the init.
     */
    var listManager: SwimListManagerProtocol {
        get {
            return tableViewHelper.listManager
        }
    }

    var swimListTableView: UITableView? {
        get {
            return tableViewHelper.tableView
        }
        set {
            tableViewHelper.tableView = newValue
            newValue?.dataSource = self
            newValue?.delegate = self
        }
    }

    /**
     The section in the UITableView where objects from the Swim list will appear.

     This defaults to 0.  You may set it from your subclass if you want to use
     section 0 for something else.  In that case, you must also override
     all the UITableViewDataSource methods and call SwimListTableViewController's
     implementation of those if and only if the given section is equal to objectSection.
     */
    var objectSection = 0


    // MARK: Lifecycle

    init?(listManager: SwimListManagerProtocol, coder aDecoder: NSCoder) {
        self.tableViewHelper = SwimListTableViewHelper(listManager: listManager)

        super.init(coder: aDecoder)

        self.tableViewHelper.delegate = self
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("Use init(listManager:coder:)")
    }

    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        listManager.startSynching()
    }

    override public func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        listManager.stopSynching()
    }


    // MARK: UITableViewDataSource / UITableViewDelegate

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        fatalError("Must be implemented by a subclass")
    }

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return objectSection + 1
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        assert(section == objectSection)
        return objects.count
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        tableViewHelper.commitEdit(editingStyle, indexPath: indexPath)
    }

    public func tableView(tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
        assert(indexPath.section == objectSection)
        listManager.setHighlightAtIndex(indexPath.row, isHighlighted: true)
    }

    public func tableView(tableView: UITableView, didUnhighlightRowAtIndexPath indexPath: NSIndexPath) {
        assert(indexPath.section == objectSection)
        listManager.setHighlightAtIndex(indexPath.row, isHighlighted: false)
    }

    public func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        assert(fromIndexPath.section == objectSection && toIndexPath.section == objectSection)
        listManager.moveObjectAtIndex(fromIndexPath.row, toIndex: toIndexPath.row)
    }

    public func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}
