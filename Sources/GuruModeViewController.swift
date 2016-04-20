//
//  GuruModeViewController.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 4/19/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Crashlytics
import Foundation
import SwiftyBeaver
import SwimSwift
import UIKit


private let log = SwiftyBeaver.self


class GuruModeViewController: UITableViewController {
    private enum Row {
        case Crash
        case DBSize(NSURL)
    }

    private var rows = [Row]()


    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = 80
        DetailTableViewCell.registerNibOnTableView(tableView)

        configureRows()
    }


    private func configureRows() {
        rows.removeAll()

        configureDBRows()

        rows.append(.Crash)
    }

    private func configureDBRows() {
        guard let dbManager = SwimGlobals.instance.dbManager else {
            return
        }
        let allStats = dbManager.statistics()

        rows.append(.DBSize(dbManager.rootDir))

        for (url, _) in allStats {
            if url == dbManager.rootDir {
                continue
            }
            rows.append(.DBSize(url))
        }
    }


    // MARK: - UITableViewDataSource, UITableViewDelegate

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        let row = rows[indexPath.row]

        switch row {
        case .Crash:
            let cell: DetailTableViewCell = DetailTableViewCell.dequeueFromTableView(tableView, forIndexPath: indexPath)
            cell.label = "Crash!"
            cell.value = ""
            return cell

        case .DBSize(let url):
            let cell: DetailTableViewCell = DetailTableViewCell.dequeueFromTableView(tableView, forIndexPath: indexPath)
            cell.label = "DB size: \(trimmedDBPath(url))"
            let dbManager = SwimGlobals.instance.dbManager!
            if let stats = dbManager.statistics()[url] {
                let formatter = NSByteCountFormatter()
                cell.value = formatter.stringFromByteCount(Int64(stats.fileSize))
            }
            else {
                cell.value = "---"
            }
            return cell
        }
    }

    private func trimmedDBPath(url: NSURL) -> String {
        let dbManager = SwimGlobals.instance.dbManager!
        let path = url.path!
        let rootPath = dbManager.rootDir.path!
        if path == rootPath {
            return "Total"
        }
        let trimmedPath = path.substringFromIndex(rootPath.endIndex)
        return trimmedPath.substringFromIndex(trimmedPath.startIndex.successor())
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        let row = rows[indexPath.row]

        switch row {
        case .Crash:
            crash()

        case .DBSize(_):
            break
        }
    }

    private func crash() {
        let prompt = UIAlertController(title: "Are you sure you want to crash?", message: "This will crash the app!  This is used to test the crash reporting features.", preferredStyle: .Alert)
        prompt.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        prompt.addAction(UIAlertAction(title: "Crash!", style: .Destructive, handler: { _ in
            log.error("Crash requested by user!")
            let when = dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * NSTimeInterval(NSEC_PER_SEC)))
            dispatch_after(when, dispatch_get_main_queue()) {
                Crashlytics.sharedInstance().crash()
            }
        }))

        presentViewController(prompt, animated: true, completion: nil)
    }
}
