//
//  UITableViewCell+Misc.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 4/19/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


extension UITableViewCell {
    class var cellIdentifier: String {
        return NSStringFromClass(self)
    }

    class func registerNibOnTableView(tableView: UITableView) {
        let cellId = cellIdentifier
        let nib = UINib(nibName: cellId, bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: cellId)
    }

    class func dequeueFromTableView<T: UITableViewCell>(tableView: UITableView, forIndexPath indexPath: NSIndexPath) -> T {
        return tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! T
    }
}
