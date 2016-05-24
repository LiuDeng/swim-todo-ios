//
//  SwimListViewController.swift
//  Swim
//
//  Created by Ewan Mellor on 2/16/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


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
public class SwimListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SwimListViewHelperDelegate {
    private let tableViewHelper = SwimListTableViewHelper()

    /**
     The Swim objects in this list.

     Equivalent to swimListManager.objects (this is just an alias for convenience).
     */
    public var swimObjects: [SwimModelProtocolBase] {
        get {
            return swimListManager.objects
        }
    }

    /**
     The downlink for this list.

     Equivalent to swimListManager.downlink (this is just an alias for convenience).
     */
    public var swimDownlink: ListDownlink? {
        return swimListManager.downlink
    }

    /**
     The scope for this list.  Set this before viewWillAppear to configure
     the list.

     Equivalent to swimListManager.laneScope (this is just an alias for convenience).
     */
    public var swimLaneScope: LaneScope? {
        get {
            return swimListManager.laneScope
        }
        set {
            swimListManager.laneScope = newValue
        }
    }

    /**
     The SwimListManager instance that we created to manage this list.
     */
    public var swimListManager: SwimListManager {
        get {
            return tableViewHelper.listManager
        }
    }

    /**
     The UITableView that we are managing.  Set this before viewWillAppear
     so that the table is updated as soon as the lane is synchronized.
     */
    public var swimListTableView: UITableView? {
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
    public var swimObjectSection = 0


    // MARK: Lifecycle

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.tableViewHelper.delegate = self
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        self.tableViewHelper.delegate = self
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

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        fatalError("Must be implemented by a subclass")
    }

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return swimObjectSection + 1
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        precondition(section == swimObjectSection)
        return swimObjects.count
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        tableViewHelper.commitEdit(editingStyle, indexPath: indexPath)
    }

    public func tableView(tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
        precondition(indexPath.section == swimObjectSection)
        swimDownlink!.setHighlightAtIndex(indexPath.row, isHighlighted: true)
    }

    public func tableView(tableView: UITableView, didUnhighlightRowAtIndexPath indexPath: NSIndexPath) {
        precondition(indexPath.section == swimObjectSection)
        swimDownlink!.setHighlightAtIndex(indexPath.row, isHighlighted: false)
    }

    public func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        precondition(fromIndexPath.section == swimObjectSection && toIndexPath.section == swimObjectSection)
        let from = fromIndexPath.row
        let to = toIndexPath.row
        if from == to {
            return
        }
        swimDownlink!.moveFromIndex(from, toIndex: to)
    }

    public func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}
