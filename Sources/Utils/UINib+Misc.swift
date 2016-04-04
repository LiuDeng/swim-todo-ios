//
//  UINib+Misc.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 4/3/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


extension UINib {
    public class func instantiateFromNib<T>(nibName: String? = nil, owner: AnyObject? = nil) -> T {
        let nibName = nibName ?? String(T)
        let objs = UINib(nibName: nibName, bundle: nil).instantiateWithOwner(owner, options: nil)
        for obj in objs {
            if let result = obj as? T {
                return result
            }
        }
        preconditionFailure()
    }
}
