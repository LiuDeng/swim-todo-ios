//
//  AckResponse.swift
//  Swim
//
//  Created by Ewan Mellor on 4/11/16.
//
//

import Recon

public class AckResponse: RoutableEnvelope, Equatable, CustomStringConvertible {
    public internal(set) var node: SwimUri!
    public let lane: SwimUri!
    public let commands: Int

    public convenience init?(value: Value) {
        guard let c = value["ack"]["commands"].integer else {
            return nil
        }
        self.init(commands: c)
    }

    public required init(commands: Int) {
        self.commands = commands
        self.node = nil
        self.lane = nil
    }

    public var recon: String {
        let reconValue = Value([Item.Attr("ack", Value(Item.Slot("commands", Value(commands))))])
        return reconValue.recon
    }

    public var description: String {
        return recon
    }
}

public func == (lhs: AckResponse, rhs: AckResponse) -> Bool {
    return lhs.commands == rhs.commands
}
