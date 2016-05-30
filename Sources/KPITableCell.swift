//
//  KPITableCell.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/29/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


class KPITableCell: UITableViewCell {
    @IBOutlet private weak var lblTitle: UILabel!
    @IBOutlet private weak var lblValue: UILabel!
    @IBOutlet private weak var lblSubtitle: UILabel!
    @IBOutlet private weak var lblDetail: UILabel!

    private var title: String {
        get {
            return lblTitle.text ?? ""
        }
        set {
            lblTitle.text = newValue
        }
    }


    private var value: String {
        get {
            return lblValue.text ?? ""
        }
        set {
            lblValue.text = newValue
        }
    }


    private var subtitle: String {
        get {
            return lblSubtitle.text ?? ""
        }
        set {
            lblSubtitle.text = newValue
        }
    }


    private var detail: String {
        get {
            return lblDetail.text ?? ""
        }
        set {
            lblDetail.text = newValue
        }
    }


    var kpi: KPIModel! {
        didSet {
            refreshCell()
        }
    }


    deinit {
        let nc = NSNotificationCenter.defaultCenter()
        nc.removeObserver(self)
    }


    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = UIColor.clearColor()

        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(refreshCell), name: MapViewController.kpisDidRefreshNotification, object: nil)
    }


    @objc func refreshCell() {
        title = kpi.title
        subtitle = kpi.subtitle
        value = kpi.value
        detail = kpi.detail

        lblDetail.hidden = detail.isEmpty
    }
}
