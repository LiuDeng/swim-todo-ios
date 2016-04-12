class RemoteLane: RemoteScope, LaneScope {
    let channel: Channel

    let hostUri: SwimUri

    let nodeUri: SwimUri

    let laneUri: SwimUri

    init(channel: Channel, host: SwimUri, node: SwimUri, lane: SwimUri) {
        self.channel = channel
        self.hostUri = host
        self.nodeUri = node
        self.laneUri = lane
    }

    func link(properties properties: LaneProperties) -> Downlink {
        let downlink = channel.link(scope: self, node: nodeUri, lane: laneUri, properties: properties)
        registerDownlink(downlink)
        return downlink
    }

    func sync(properties properties: LaneProperties) -> Downlink {
        let downlink = channel.sync(scope: self, node: nodeUri, lane: laneUri, properties: properties)
        registerDownlink(downlink)
        return downlink
    }

    func syncList(properties properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> ListDownlink {
        let downlink = channel.syncList(scope: self, node: nodeUri, lane: laneUri, properties: properties, objectMaker: objectMaker)
        registerDownlink(downlink as! RemoteDownlink)
        return downlink
    }

    func syncMap(properties properties: LaneProperties, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        let downlink = channel.syncMap(scope: self, node: nodeUri, lane: laneUri, properties: properties, primaryKey: primaryKey)
        registerDownlink(downlink)
        return downlink
    }
    
    func command(body body: SwimValue) {
        channel.command(node: nodeUri, lane: laneUri, body: body)
    }
}
