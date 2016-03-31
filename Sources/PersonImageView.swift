//
//  PersonImageView.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 3/31/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


class PersonImageView: UIView {
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblInitials: UILabel!

    var initials: String {
        get {
            return lblInitials.text ?? ""
        }
        set {
            lblInitials.text = newValue
            backgroundColor = calcBackgroundColor(newValue)
        }
    }


    override func awakeFromNib() {
        imgView.alpha = 0.0
        lblInitials.alpha = 0.0
        layer.borderColor = UIColor.darkGrayColor().CGColor
        layer.borderWidth = 1.0
    }
}


private func calcBackgroundColor(s: String) -> UIColor {
    let hash = s.hash
    let hue = CGFloat(36 + (hash % 212)) / 256.0  // Avoid browns (degrees 0-50) because they don't look great.
    return UIColor(hue: hue, saturation: 0.5, brightness: 0.7, alpha: 1.0)
}
