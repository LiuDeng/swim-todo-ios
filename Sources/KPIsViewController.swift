//
//  KPIsViewController.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/29/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


private let kCellIdentifier = "Cell"
private let kRowHeight = CGFloat(154)
private let kExtendedRowHeight = CGFloat(175)


class KPIsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!

    var kpis = [KPIModel]() {
        didSet {
            tableView?.reloadData()
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.layer.cornerRadius = 4

        tableView.estimatedRowHeight = kRowHeight
        tableView.registerNib(UINib(nibName: "KPITableCell", bundle: nil), forCellReuseIdentifier: kCellIdentifier)
    }


    @IBAction func viewTapped() {
        dismissViewControllerAnimated(true, completion: nil)
    }


    // MARK: - UITableViewDataSource / UITableViewDelegate

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return kpis.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let kpi = kpis[indexPath.row]

        let cell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier, forIndexPath: indexPath) as! KPITableCell
        cell.kpi = kpi
        return cell
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let kpi = kpis[indexPath.row]
        return (kpi.detail.isEmpty ? kRowHeight : kExtendedRowHeight)
    }
}
