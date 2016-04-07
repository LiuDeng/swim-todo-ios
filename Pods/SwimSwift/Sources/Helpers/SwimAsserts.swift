//
//  SwimAsserts.swift
//  Swim
//
//  Created by Ewan Mellor on 4/7/16.
//
//

import Foundation


func SwimAssertOnMainThread() {
    assert(NSThread.isMainThread(), "Must be on main thread.")
}
