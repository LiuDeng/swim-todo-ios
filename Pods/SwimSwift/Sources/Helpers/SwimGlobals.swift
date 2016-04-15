//
//  SwimGlobals.swift
//  Swim
//
//  Created by Ewan Mellor on 3/29/16.
//
//

import Foundation


public class SwimGlobals {
    public static let instance = SwimGlobals()

    private init() {
    }

    public var networkConditionMonitor: SwimNetworkConditionMonitor!

    public var dbManager: SwimDBManager?
}
