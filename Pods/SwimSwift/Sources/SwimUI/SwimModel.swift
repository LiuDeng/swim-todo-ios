//
//  SwimModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation


public protocol SwimModelProtocol: class, Equatable {
    init()
    init?(swimValue: SwimValue)
    func swim_toSwimValue() -> SwimValue
    func swim_updateWithSwimValue(swimValue: SwimValue)
}


public class SwimModelBase: SwimModelProtocol {
    required public init() {
    }

    required public init?(swimValue: SwimValue) {
    }

    public func swim_toSwimValue() -> SwimValue {
        return SwimValue(String(self))
    }

    public func swim_updateWithSwimValue(swimValue: SwimValue) {
        fatalError("Must be implemented by a subclass")
    }
}

public func ==(lhs: SwimModelBase, rhs: SwimModelBase) -> Bool {
    let lVal = lhs.swim_toSwimValue()
    let rVal = rhs.swim_toSwimValue()
    return lVal == rVal
}
