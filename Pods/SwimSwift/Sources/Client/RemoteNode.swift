import Recon

class RemoteNode: RemoteScope, NodeScope {
    let channel: Channel

    let hostUri: SwimUri

    let nodeUri: SwimUri

    init(channel: Channel, host: SwimUri, node: SwimUri) {
        self.channel = channel
        self.hostUri = host
        self.nodeUri = node
    }

    func scope(lane lane: SwimUri) -> LaneScope {
        return RemoteLane(channel: channel, host: hostUri, node: nodeUri, lane: lane)
    }

    func link(lane lane: SwimUri, prio: Double) -> Downlink {
        let downlink = channel.link(scope: self, node: nodeUri, lane: lane, prio: prio)
        registerDownlink(downlink)
        return downlink
    }

    func sync(lane lane: SwimUri, prio: Double) -> Downlink {
        let downlink = channel.sync(scope: self, node: nodeUri, lane: lane, prio: prio)
        registerDownlink(downlink)
        return downlink
    }

    func syncMap(lane lane: SwimUri, prio: Double, primaryKey: Value -> Value) -> MapDownlink {
        let downlink = channel.syncMap(scope: self, node: nodeUri, lane: lane, prio: prio, primaryKey: primaryKey)
        registerDownlink(downlink)
        return downlink
    }

    func command(lane lane: SwimUri, body: Value) {
        channel.command(node: nodeUri, lane: lane, body: body)
    }
}
