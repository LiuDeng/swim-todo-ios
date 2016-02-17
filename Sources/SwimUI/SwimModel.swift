//
//  SwimModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import Recon

public protocol SwimModelProtocol: class, Equatable {
    init()
    init?(reconValue: ReconValue)
    func toReconValue() -> ReconValue
    func update(reconValue: ReconValue)
}

public class SwimModel: SwimModelProtocol {
    required public init() {
    }

    required public init?(reconValue: ReconValue) {
    }

    public func toReconValue() -> ReconValue {
        return Value(String(self))
    }

    public func update(reconValue: ReconValue) {
        assertionFailure("Must be implemented by a subclass")
    }
}

public func ==(lhs: SwimModel, rhs: SwimModel) -> Bool {
    let lVal = lhs.toReconValue()
    let rVal = rhs.toReconValue()
    return lVal == rVal
}
