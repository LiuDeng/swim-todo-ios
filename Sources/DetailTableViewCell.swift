//
//  DetailTableViewCell.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 4/19/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


@objc(DetailTableViewCell)
class DetailTableViewCell: UITableViewCell {
    @IBOutlet private weak var lblLabel: UILabel!
    @IBOutlet private weak var lblValue: UILabel!

    var label: String {
        get {
            return lblLabel.text ?? ""
        }
        set {
            lblLabel.text = newValue
        }
    }

    var value: String {
        get {
            return lblValue.text ?? ""
        }
        set {
            lblValue.text = newValue
        }
    }
}
