//
//  SwimModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation


public protocol SwimModelProtocolBase: class {
    /**
     Whether this object is "highlighted".  This is used for objects in
     table views to indicate that the row is being highlighted or edited.
     */
    var isHighlighted: Bool { get set }

    func swim_toSwimValue() -> SwimValue
    func swim_updateWithSwimValue(swimValue: SwimValue)
}

public protocol SwimModelProtocol: SwimModelProtocolBase, Equatable {
    init()
    init?(swimValue: SwimValue)
}


public class SwimModelBase: SwimModelProtocol, CustomStringConvertible {
    public var isHighlighted: Bool = false

    required public init() {
    }

    required public init?(swimValue: SwimValue) {
        swim_updateWithSwimValue(swimValue)
    }

    public func swim_toSwimValue() -> SwimValue {
        let json = swim_toJSON()
        return SwimValue(json: json)
    }

    public func swim_toJSON() -> [String: AnyObject] {
        var json = [String: AnyObject]()
        if isHighlighted {
            json["isHighlighted"] = true
        }
        return json
    }

    public func swim_updateWithSwimValue(swimValue: SwimValue) {
        guard let json = swimValue.json as? [String: AnyObject] else {
            return
        }

        swim_updateWithJSON(json)
    }

    public func swim_updateWithJSON(json: [String: AnyObject]) {
        isHighlighted = ((json["isHighlighted"] as? String) == "true")
    }

    public var description: String {
        return swim_toSwimValue().recon
    }
}

public func ==(lhs: SwimModelBase, rhs: SwimModelBase) -> Bool {
    let lVal = lhs.swim_toSwimValue()
    let rVal = rhs.swim_toSwimValue()
    return lVal == rVal
}
