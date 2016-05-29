//
//  UIColor+SwimTodo.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/28/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation


extension UIColor {
    private static func fk_rgb(r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1.0) -> UIColor {
        return UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: a)
    }

    static func st_route() -> UIColor {
        return UIColor.fk_rgb(255, 190, 51, 0.9)
    }
}
