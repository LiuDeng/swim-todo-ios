//
//  GuruModeViewController.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 4/19/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import SwimSwift
import UIKit


class GuruModeViewController: UITableViewController {
    private enum Row {
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
}
