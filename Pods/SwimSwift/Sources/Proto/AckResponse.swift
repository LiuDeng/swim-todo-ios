//
//  AckResponse.swift
//  Swim
//
//  Created by Ewan Mellor on 4/11/16.
//
//

import Recon

public class AckResponse: RoutableEnvelope, Equatable, CustomStringConvertible {
    public internal(set) var node: SwimUri
    public let lane: SwimUri
    public let commands: Int

    public convenience init?(value: Value) {
        guard let ack = value["ack"].record, n = ack["node"].uri, l = ack["lane"].uri, c = ack["commands"].integer else {
            return nil
        }
        self.init(node: n, lane: l, commands: c)
    }

    public required init(node: SwimUri, lane: SwimUri, commands: Int) {
        self.node = node
        self.lane = lane
        self.commands = commands
    }

    public var recon: String {
        let reconValue = Value([Item.Attr("ack", Value(Item.Slot("node", Value(node)), Item.Slot("lane", Value(lane)), Item.Slot("commands", Value(commands))))])
        return reconValue.recon
    }

    public var description: String {
        return recon
    }
}

public func == (lhs: AckResponse, rhs: AckResponse) -> Bool {
    return (
        lhs.node == rhs.node &&
        lhs.lane == rhs.lane &&
        lhs.commands == rhs.commands
    )
}
