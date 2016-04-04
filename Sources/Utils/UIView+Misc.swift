//
//  UIView+Misc.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 3/31/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


extension UIView {
    public func anchorSubview(subview: UIView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        subview.frame = CGRect(origin: CGPointZero, size: frame.size)

        let views = ["subview": subview]
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[subview]-0-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[subview]-0-|", options: [], metrics: nil, views: views))
    }

    public func addSelfSubviewFromNib(nibName: String? = nil) -> Self {
        let subview = self.dynamicType.viewFromNib(nibName, owner: self as UIView)

        addSubview(subview)
        anchorSubview(subview)

        return subview
    }

    public class func viewFromNib(nibName: String? = nil, owner: AnyObject? = nil) -> Self {
        return UINib.instantiateFromNib(nibName, owner: owner)
    }
}
