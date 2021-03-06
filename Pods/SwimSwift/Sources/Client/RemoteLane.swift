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
        return channel.link(node: nodeUri, lane: laneUri, properties: properties)
    }

    func sync(properties properties: LaneProperties) -> Downlink {
        return channel.sync(node: nodeUri, lane: laneUri, properties: properties)
    }

    func syncList(properties properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> ListDownlink {
        return channel.syncList(node: nodeUri, lane: laneUri, properties: properties, objectMaker: objectMaker)
    }

    func syncMap(properties properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> MapDownlink {
        return syncMap(properties: properties, objectMaker: objectMaker, primaryKey: nil)
    }

    func syncMap(properties properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?), primaryKey: (SwimModelProtocolBase -> SwimValue)? = nil) -> MapDownlink {
        var pk = primaryKey
        if pk == nil {
            pk = { (obj: SwimModelProtocolBase) in
                return SwimValue(obj.swimId ?? "")
            }
        }
        return channel.syncMap(node: nodeUri, lane: laneUri, properties: properties, objectMaker: objectMaker, primaryKey: pk!)
    }
    
    func syncValue(properties properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> ValueDownlink {
        return channel.syncValue(node: nodeUri, lane: laneUri, properties: properties, objectMaker: objectMaker)
    }

    func command(body body: SwimValue) {
        channel.command(node: nodeUri, lane: laneUri, body: body)
    }

    override func close() {
        channel.closeDownlinks(node: nodeUri, lane: laneUri)
    }
}
