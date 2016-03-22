class RemoteHost: RemoteScope, HostScope {
    let channel: Channel

    let hostUri: SwimUri

    init(channel: Channel, host: SwimUri) {
        self.channel = channel
        self.hostUri = host
    }

    func scope(node nodeUri: SwimUri) -> NodeScope {
        return RemoteNode(channel: channel, host: hostUri, node: nodeUri)
    }

    func scope(node nodeUri: SwimUri, lane laneUri: SwimUri) -> LaneScope {
        return RemoteLane(channel: channel, host: hostUri, node: nodeUri, lane: laneUri)
    }

    func downlink() -> DownlinkBuilder {
        return RemoteDownlinkBuilder(channel: channel, scope: self, host: hostUri)
    }

    func link(node nodeUri: SwimUri, lane laneUri: SwimUri, prio: Double) -> Downlink {
        let downlink = channel.link(scope: self, node: nodeUri, lane: laneUri, prio: prio)
        registerDownlink(downlink)
        return downlink
    }

    func sync(node nodeUri: SwimUri, lane laneUri: SwimUri, prio: Double) -> Downlink {
        let downlink = channel.sync(scope: self, node: nodeUri, lane: laneUri, prio: prio)
        registerDownlink(downlink)
        return downlink
    }

    func syncList(node nodeUri: SwimUri, lane laneUri: SwimUri, prio: Double) -> ListDownlink {
        let downlink = channel.syncList(scope: self, node: nodeUri, lane: laneUri, prio: prio)
        registerDownlink(downlink)
        return downlink
    }

    func syncMap(node nodeUri: SwimUri, lane laneUri: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        let downlink = channel.syncMap(scope: self, node: nodeUri, lane: laneUri, prio: prio, primaryKey: primaryKey)
        registerDownlink(downlink)
        return downlink
    }

    func command(node nodeUri: SwimUri, lane laneUri: SwimUri, body: SwimValue) {
        channel.command(node: nodeUri, lane: laneUri, body: body)
    }
}
